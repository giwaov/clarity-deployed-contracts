;; traits
(use-trait ft-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; constants
(define-constant MINIMUM_LIQUIDITY u1000)
(define-constant THIS_CONTRACT (as-contract tx-sender))
(define-constant FEES_DENOM u10000)

;; errors
(define-constant ERR_POOL_ALREADY_EXISTS (err u200))
(define-constant ERR_INCORRECT_TOKEN_ORDERING (err u201))
(define-constant ERR_INSUFFICIENT_LIQUIDITY_MINTED (err u202))
(define-constant ERR_INSUFFICIENT_LIQUIDITY_OWNED (err u203))
(define-constant ERR_INSUFFICIENT_LIQUIDITY_BURNED (err u204))
(define-constant ERR_INSUFFICIENT_INPUT_AMOUNT (err u205))
(define-constant ERR_INSUFFICIENT_LIQUIDITY_FOR_SWAP (err u206))
(define-constant ERR_INSUFFICIENT_1_AMOUNT (err u207))
(define-constant ERR_INSUFFICIENT_0_AMOUNT (err u208))

;; mappings
(define-map pools
    (buff 20)
    { 
        token-0: principal,
        token-1: principal,
        fee: uint,
        liquidity: uint,
        balance-0: uint,
        balance-1: uint
    }
)

(define-map positions 
    { 
        pool-id: (buff 20),
        owner: principal
    } 
    { 
        liquidity: uint
    }
)

;; read-only functions
(define-read-only (get-pool-id (pool-info {token-0: <ft-trait>, token-1: <ft-trait>, fee: uint})) 
    (let 
        (
            (buff (unwrap-panic (to-consensus-buff? pool-info)))
            (pool-id (hash160 buff))
        )
        pool-id
    )
)

(define-read-only (get-position-liquidity (pool-id (buff 20)) (owner principal))
    (let
        (
            (position (map-get? positions { pool-id: pool-id, owner: owner }))
            (existing-owner-liquidity (if (is-some position) (unwrap-panic position) {liquidity: u0}))
        )
        (ok (get liquidity existing-owner-liquidity))
    )
)

(define-read-only (get-pool-data (pool-id (buff 20))) 
    (let 
        (
            (pool-data (map-get? pools pool-id))
        )
        (ok pool-data)
    )
)

;; private functions
(define-private (correct-token-ordering (token-0 principal) (token-1 principal)) 
    (let
        (
            (token-0-buff (unwrap-panic (to-consensus-buff? token-0)))
            (token-1-buff (unwrap-panic (to-consensus-buff? token-1)))
        )
        (asserts! (< token-0-buff token-1-buff) ERR_INCORRECT_TOKEN_ORDERING)
        (ok true)
    )
)

(define-private (get-amounts (amount-0-desired uint) (amount-1-desired uint) (amount-0-min uint) (amount-1-min uint) (balance-0 uint) (balance-1 uint)) 
    (let
        (
            (amount-1-given-0 (/ (* amount-0-desired balance-1) balance-0))
            (amount-0-given-1 (/ (* amount-1-desired balance-0) balance-1))
        )
        (if 
            (<= amount-1-given-0 amount-1-desired)
            (begin 
                (asserts! (>= amount-1-given-0 amount-1-min) ERR_INSUFFICIENT_1_AMOUNT)
                (ok { amount-0: amount-0-desired, amount-1: amount-1-given-0 })
            )
            (begin 
                (asserts! (<= amount-0-given-1 amount-0-desired) ERR_INSUFFICIENT_0_AMOUNT)
                (asserts! (>= amount-0-given-1 amount-0-min) ERR_INSUFFICIENT_0_AMOUNT)
                (ok { amount-0: amount-0-given-1, amount-1: amount-1-desired })
            )
        )
    )
)

(define-private (min (a uint) (b uint)) 
    (if (< a b) a b)
)

;; public functions
(define-public (create-pool (token-0 <ft-trait>) (token-1 <ft-trait>) (fee uint)) 
    (let (
        (pool-info {token-0: token-0, token-1: token-1, fee: fee})
        (pool-id (get-pool-id pool-info))
        (pool-does-not-exist (is-none (map-get? pools pool-id)))
        (token-0-principal (contract-of token-0))
        (token-1-principal (contract-of token-1))
        (pool-data {
            token-0: token-0-principal,
            token-1: token-1-principal,
            fee: fee,
            liquidity: u0,
            balance-0: u0,
            balance-1: u0
        })
    ) 
    (asserts! pool-does-not-exist ERR_POOL_ALREADY_EXISTS)
    (asserts! (is-ok (correct-token-ordering token-0-principal token-1-principal)) ERR_INCORRECT_TOKEN_ORDERING)
    
    (map-set pools pool-id pool-data)
    (print { action: "create-pool", data: pool-data})
    (ok true)
    )
)

(define-public (add-liquidity (token-0 <ft-trait>) (token-1 <ft-trait>) (fee uint) (amount-0-desired uint) (amount-1-desired uint) (amount-0-min uint) (amount-1-min uint))
    (let
        (
            (pool-info {token-0: token-0, token-1: token-1, fee: fee})
            (pool-id (get-pool-id pool-info))
            (pool-data (unwrap! (map-get? pools pool-id) (err u0)))
            (sender tx-sender)
            (pool-liquidity (get liquidity pool-data))
            (balance-0 (get balance-0 pool-data))
            (balance-1 (get balance-1 pool-data))
            (user-liquidity (unwrap! (get-position-liquidity pool-id sender) (err u0)))
            (is-initial-liquidity (is-eq pool-liquidity u0))
            (amounts 
                (if 
                    is-initial-liquidity
                    {amount-0: amount-0-desired, amount-1: amount-1-desired}
                    (unwrap! (get-amounts amount-0-desired amount-1-desired amount-0-min amount-1-min balance-0 balance-1) (err u0))
                )
            )
            (amount-0 (get amount-0 amounts))
            (amount-1 (get amount-1 amounts))
            (new-liquidity 
                (if 
                    is-initial-liquidity
                    (- (sqrti (* amount-0 amount-1)) MINIMUM_LIQUIDITY)
                    (min (/ (* amount-0 pool-liquidity) balance-0) (/ (* amount-1 pool-liquidity) balance-1))
                )
            )
            (new-pool-liquidity
                (if
                    is-initial-liquidity
                    (+ new-liquidity MINIMUM_LIQUIDITY)
                    new-liquidity
                )
            )
        )
        (asserts! (> new-liquidity u0) ERR_INSUFFICIENT_LIQUIDITY_MINTED)
        (try! (contract-call? token-0 transfer amount-0 sender THIS_CONTRACT none))
        (try! (contract-call? token-1 transfer amount-1 sender THIS_CONTRACT none))
        (map-set positions 
            {pool-id: pool-id, owner: sender}
            {liquidity: (+ user-liquidity new-liquidity)}
        )
        (map-set pools pool-id (merge pool-data {
            liquidity: (+ pool-liquidity new-pool-liquidity),
            balance-0: (+ balance-0 amount-0),
            balance-1: (+ balance-1 amount-1)
        }))
        (print { action: "add-liquidity", pool-id: pool-id, amount-0: amount-0, amount-1: amount-1, liquidity: (+ user-liquidity new-liquidity) })
        (ok true)
    )
)

(define-public (remove-liquidity (token-0 <ft-trait>) (token-1 <ft-trait>) (fee uint) (liquidity uint))
    (let
        (
            (pool-info {token-0: token-0, token-1: token-1, fee: fee})
            (pool-id (get-pool-id pool-info))
            (pool-data (unwrap! (map-get? pools pool-id) (err u0)))
            (sender tx-sender)
            (pool-liquidity (get liquidity pool-data))
            (balance-0 (get balance-0 pool-data))
            (balance-1 (get balance-1 pool-data))
            (user-liquidity (unwrap! (get-position-liquidity pool-id sender) (err u0)))
            (amount-0 (/ (* liquidity balance-0) pool-liquidity))
            (amount-1 (/ (* liquidity balance-1) pool-liquidity))
        )
        (asserts! (>= user-liquidity liquidity) ERR_INSUFFICIENT_LIQUIDITY_OWNED)
        (asserts! (> amount-0 u0) ERR_INSUFFICIENT_LIQUIDITY_BURNED)
        (asserts! (> amount-1 u0) ERR_INSUFFICIENT_LIQUIDITY_BURNED)
        (try! (as-contract (contract-call? token-0 transfer amount-0 THIS_CONTRACT sender none)))
        (try! (as-contract (contract-call? token-1 transfer amount-1 THIS_CONTRACT sender none)))
        (map-set positions 
            {pool-id: pool-id, owner: sender}
            {liquidity: (- user-liquidity liquidity)}
        )
        (map-set pools pool-id (merge pool-data {
            liquidity: (- pool-liquidity liquidity),
            balance-0: (- balance-0 amount-0),
            balance-1: (- balance-1 amount-1)
        }))
        (print { action: "remove-liquidity", pool-id: pool-id, amount-0: amount-0, amount-1: amount-1, liquidity: liquidity })
        (ok true)
    )
)

(define-public (swap (token-0 <ft-trait>) (token-1 <ft-trait>) (fee uint) (input-amount uint) (zero-for-one bool)) 
    (let
        (
            (pool-info {token-0: token-0, token-1: token-1, fee: fee})
            (pool-id (get-pool-id pool-info))
            (pool-data (unwrap! (map-get? pools pool-id) (err u0)))
            (sender tx-sender)
            (pool-liquidity (get liquidity pool-data))
            (balance-0 (get balance-0 pool-data))
            (balance-1 (get balance-1 pool-data))
            (k (* balance-0 balance-1))
            (input-token (if zero-for-one token-0 token-1))
            (output-token (if zero-for-one token-1 token-0))
            (input-balance (if zero-for-one balance-0 balance-1))
            (output-balance (if zero-for-one balance-1 balance-0))
            (output-amount (- output-balance (/ k (+ input-balance input-amount))))
            (fees (/ (* output-amount fee) FEES_DENOM))
            (output-amount-sub-fees (- output-amount fees))
            (balance-0-post-swap (if zero-for-one (+ balance-0 input-amount) (- balance-0 output-amount-sub-fees)))
            (balance-1-post-swap (if zero-for-one (- balance-1 output-amount-sub-fees) (+ balance-1 input-amount)))
        )
        (asserts! (> input-amount u0) ERR_INSUFFICIENT_INPUT_AMOUNT)
        (asserts! (> output-amount-sub-fees u0) ERR_INSUFFICIENT_LIQUIDITY_FOR_SWAP)
        (asserts! (< output-amount-sub-fees output-balance) ERR_INSUFFICIENT_LIQUIDITY_FOR_SWAP)
        (try! (contract-call? input-token transfer input-amount sender THIS_CONTRACT none))
        (try! (as-contract (contract-call? output-token transfer output-amount-sub-fees THIS_CONTRACT sender none)))
        (map-set pools pool-id (merge pool-data {
            balance-0: balance-0-post-swap,
            balance-1: balance-1-post-swap
        }))
        (print { action: "swap", pool-id: pool-id, input-amount: input-amount })
        (ok true)
    )
)