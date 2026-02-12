;; StackStream Micropayment Gateway Contract
;; Facilitates instant pay-per-view content access with minimal friction

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u300))
(define-constant err-not-found (err u301))
(define-constant err-already-exists (err u302))
(define-constant err-insufficient-funds (err u303))
(define-constant err-unauthorized (err u304))
(define-constant err-invalid-input (err u305))
(define-constant err-expired (err u306))
(define-constant err-already-accessed (err u307))

;; Fee constants
(define-constant transaction-fee-percent u500) ;; 5% = 500/10000
(define-constant min-transaction-fee u50000) ;; 0.05 STX minimum
(define-constant batch-discount-percent u1000) ;; 10% = 1000/10000
(define-constant batch-threshold u10) ;; 10+ items for discount

;; Price range constants (in microSTX)
(define-constant min-content-price u100000) ;; 0.1 STX
(define-constant max-content-price u10000000) ;; 10 STX

;; Access token validity (in blocks, ~24 hours)
(define-constant access-token-validity u144)

;; Data Variables
(define-data-var total-transactions uint u0)
(define-data-var total-volume uint u0)
(define-data-var platform-treasury principal contract-owner)
(define-data-var next-access-token-id uint u0)

;; Data Maps

;; Content access tokens (time-limited)
(define-map access-tokens
    uint ;; token-id
    {
        purchaser: principal,
        creator: principal,
        content-id: uint,
        purchase-block: uint,
        expiry-block: uint,
        amount-paid: uint,
        is-active: bool,
        access-key: (buff 32)
    }
)

;; User access token tracking
(define-map user-access-tokens
    {purchaser: principal, creator: principal, content-id: uint}
    uint ;; token-id
)

;; Transaction history
(define-map transactions
    uint ;; transaction-id
    {
        purchaser: principal,
        creator: principal,
        content-ids: (list 10 uint),
        total-amount: uint,
        platform-fee: uint,
        creator-amount: uint,
        transaction-block: uint,
        is-batch: bool
    }
)

;; Creator payment stats
(define-map creator-payment-stats
    principal
    {
        total-transactions: uint,
        total-revenue: uint,
        total-content-sold: uint
    }
)

;; User purchase history count
(define-map user-transaction-count principal uint)

;; Content bundles
(define-map content-bundles
    {creator: principal, bundle-id: uint}
    {
        content-ids: (list 10 uint),
        bundle-price: uint,
        discount-percent: uint,
        is-active: bool,
        created-at: uint
    }
)

(define-map creator-bundle-count principal uint)

;; Gift tracking
(define-map gift-access
    {gifter: principal, recipient: principal, gift-id: uint}
    {
        creator: principal,
        content-id: uint,
        amount: uint,
        gifted-at: uint,
        is-claimed: bool
    }
)

(define-map user-gift-count principal uint)

;; Private Functions

(define-private (calculate-fee (amount uint))
    (let ((calculated-fee (/ (* amount transaction-fee-percent) u10000)))
        (if (< calculated-fee min-transaction-fee)
            min-transaction-fee
            calculated-fee
        )
    )
)

(define-private (calculate-creator-amount (amount uint) (fee uint))
    (- amount fee)
)

(define-private (apply-batch-discount (total-amount uint) (item-count uint))
    (if (>= item-count batch-threshold)
        (let ((discount (/ (* total-amount batch-discount-percent) u10000)))
            (- total-amount discount)
        )
        total-amount
    )
)

(define-private (generate-access-key (purchaser principal) (content-id uint) (block uint))
    ;; Simple hash generation using available data
    (sha256 (concat 
        (concat (unwrap-panic (to-consensus-buff? purchaser)) 
                (unwrap-panic (to-consensus-buff? content-id)))
        (unwrap-panic (to-consensus-buff? block))
    ))
)

(define-private (update-creator-payment-stats (creator principal) (amount uint) (content-count uint))
    (let (
        (stats (default-to 
            {total-transactions: u0, total-revenue: u0, total-content-sold: u0}
            (map-get? creator-payment-stats creator)
        ))
    )
        (map-set creator-payment-stats creator {
            total-transactions: (+ (get total-transactions stats) u1),
            total-revenue: (+ (get total-revenue stats) amount),
            total-content-sold: (+ (get total-content-sold stats) content-count)
        })
        true
    )
)

(define-private (process-payment (amount uint) (creator principal))
    (let (
        (fee (calculate-fee amount))
        (creator-amount (calculate-creator-amount amount fee))
    )
        ;; Transfer to creator
        (try! (stx-transfer? creator-amount tx-sender creator))
        
        ;; Transfer fee to platform
        (try! (stx-transfer? fee tx-sender (var-get platform-treasury)))
        
        (ok {fee: fee, creator-amount: creator-amount})
    )
)

;; Public Functions

;; Purchase single content piece
(define-public (purchase-content (creator principal) (content-id uint) (price uint))
    (let (
        (purchaser tx-sender)
        (access-key {purchaser: purchaser, creator: creator, content-id: content-id})
    )
        ;; Validate inputs
        (asserts! (and (>= price min-content-price) (<= price max-content-price)) err-invalid-input)
        (asserts! (is-none (map-get? user-access-tokens access-key)) err-already-accessed)
        
        ;; Process payment
        (let ((payment-result (try! (process-payment price creator))))
            
            ;; Generate access token
            (let (
                (token-id (var-get next-access-token-id))
                (access-key-hash (generate-access-key purchaser content-id stacks-block-height))
            )
                (map-set access-tokens token-id {
                    purchaser: purchaser,
                    creator: creator,
                    content-id: content-id,
                    purchase-block: stacks-block-height,
                    expiry-block: (+ stacks-block-height access-token-validity),
                    amount-paid: price,
                    is-active: true,
                    access-key: access-key-hash
                })
                
                ;; Map user to token
                (map-set user-access-tokens access-key token-id)
                
                ;; Increment token ID
                (var-set next-access-token-id (+ token-id u1))
                
                ;; Record transaction
                (let ((tx-count (var-get total-transactions)))
                    (map-set transactions tx-count {
                        purchaser: purchaser,
                        creator: creator,
                        content-ids: (list content-id),
                        total-amount: price,
                        platform-fee: (get fee payment-result),
                        creator-amount: (get creator-amount payment-result),
                        transaction-block: stacks-block-height,
                        is-batch: false
                    })
                    (var-set total-transactions (+ tx-count u1))
                )
                
                ;; Update user transaction count
                (map-set user-transaction-count purchaser 
                    (+ (default-to u0 (map-get? user-transaction-count purchaser)) u1))
                
                ;; Update stats
                (update-creator-payment-stats creator (get creator-amount payment-result) u1)
                (var-set total-volume (+ (var-get total-volume) price))
                
                (ok token-id)
            )
        )
    )
)

;; Purchase content bundle with batch discount
(define-public (purchase-batch (creator principal) (content-ids (list 10 uint)) (total-price uint))
    (let (
        (purchaser tx-sender)
        (item-count (len content-ids))
        (discounted-price (apply-batch-discount total-price item-count))
    )
        ;; Validate inputs
        (asserts! (> item-count u0) err-invalid-input)
        (asserts! (and (>= discounted-price min-content-price) 
                      (<= discounted-price (* max-content-price item-count))) 
                  err-invalid-input)
        
        ;; Process payment with discount
        (let ((payment-result (try! (process-payment discounted-price creator))))
            
            ;; Record transaction
            (let ((tx-count (var-get total-transactions)))
                (map-set transactions tx-count {
                    purchaser: purchaser,
                    creator: creator,
                    content-ids: content-ids,
                    total-amount: discounted-price,
                    platform-fee: (get fee payment-result),
                    creator-amount: (get creator-amount payment-result),
                    transaction-block: stacks-block-height,
                    is-batch: true
                })
                (var-set total-transactions (+ tx-count u1))
            )
            
            ;; Update stats
            (update-creator-payment-stats creator (get creator-amount payment-result) item-count)
            (var-set total-volume (+ (var-get total-volume) discounted-price))
            
            ;; Update user transaction count
            (map-set user-transaction-count purchaser 
                (+ (default-to u0 (map-get? user-transaction-count purchaser)) u1))
            
            (ok true)
        )
    )
)

;; Create content bundle
(define-public (create-bundle (content-ids (list 10 uint)) 
                              (bundle-price uint) 
                              (discount-percent uint))
    (let (
        (creator tx-sender)
        (bundle-count (default-to u0 (map-get? creator-bundle-count creator)))
        (bundle-id (+ bundle-count u1))
    )
        ;; Validate inputs
        (asserts! (> (len content-ids) u1) err-invalid-input)
        (asserts! (> bundle-price u0) err-invalid-input)
        (asserts! (<= discount-percent u5000) err-invalid-input) ;; Max 50% discount
        
        ;; Create bundle
        (map-set content-bundles {creator: creator, bundle-id: bundle-id} {
            content-ids: content-ids,
            bundle-price: bundle-price,
            discount-percent: discount-percent,
            is-active: true,
            created-at: stacks-block-height
        })
        
        ;; Update bundle count
        (map-set creator-bundle-count creator bundle-id)
        
        (ok bundle-id)
    )
)

;; Purchase bundle by ID
(define-public (purchase-bundle (creator principal) (bundle-id uint))
    (let (
        (purchaser tx-sender)
        (bundle-key {creator: creator, bundle-id: bundle-id})
        (bundle-data (unwrap! (map-get? content-bundles bundle-key) err-not-found))
    )
        ;; Validate bundle
        (asserts! (get is-active bundle-data) err-invalid-input)
        
        ;; Purchase using batch function
        (try! (purchase-batch creator 
                             (get content-ids bundle-data) 
                             (get bundle-price bundle-data)))
        
        (ok true)
    )
)

;; Gift content access
(define-public (gift-content (recipient principal) 
                            (creator principal) 
                            (content-id uint) 
                            (price uint))
    (let (
        (gifter tx-sender)
        (gift-count (default-to u0 (map-get? user-gift-count gifter)))
        (gift-id (+ gift-count u1))
    )
        ;; Validate inputs
        (asserts! (not (is-eq gifter recipient)) err-invalid-input)
        (asserts! (and (>= price min-content-price) (<= price max-content-price)) err-invalid-input)
        
        ;; Process payment
        (let ((payment-result (try! (process-payment price creator))))
            
            ;; Create gift record
            (map-set gift-access {gifter: gifter, recipient: recipient, gift-id: gift-id} {
                creator: creator,
                content-id: content-id,
                amount: price,
                gifted-at: stacks-block-height,
                is-claimed: false
            })
            
            ;; Update gift count
            (map-set user-gift-count gifter gift-id)
            
            ;; Update stats
            (update-creator-payment-stats creator (get creator-amount payment-result) u1)
            (var-set total-volume (+ (var-get total-volume) price))
            
            (ok gift-id)
        )
    )
)

;; Claim gifted content
(define-public (claim-gift (gifter principal) (gift-id uint))
    (let (
        (recipient tx-sender)
        (gift-key {gifter: gifter, recipient: recipient, gift-id: gift-id})
        (gift-data (unwrap! (map-get? gift-access gift-key) err-not-found))
    )
        ;; Validate gift
        (asserts! (not (get is-claimed gift-data)) err-already-accessed)
        
        ;; Generate access token for recipient
        (let (
            (token-id (var-get next-access-token-id))
            (access-key-hash (generate-access-key recipient (get content-id gift-data) stacks-block-height))
            (access-key {purchaser: recipient, creator: (get creator gift-data), content-id: (get content-id gift-data)})
        )
            (map-set access-tokens token-id {
                purchaser: recipient,
                creator: (get creator gift-data),
                content-id: (get content-id gift-data),
                purchase-block: stacks-block-height,
                expiry-block: (+ stacks-block-height access-token-validity),
                amount-paid: (get amount gift-data),
                is-active: true,
                access-key: access-key-hash
            })
            
            ;; Map user to token
            (map-set user-access-tokens access-key token-id)
            
            ;; Mark gift as claimed
            (map-set gift-access gift-key
                (merge gift-data {is-claimed: true})
            )
            
            ;; Increment token ID
            (var-set next-access-token-id (+ token-id u1))
            
            (ok token-id)
        )
    )
)

;; Verify access token
(define-public (verify-access (token-id uint))
    (let (
        (token-data (unwrap! (map-get? access-tokens token-id) err-not-found))
    )
        ;; Check if token is valid
        (asserts! (get is-active token-data) err-expired)
        (asserts! (<= stacks-block-height (get expiry-block token-data)) err-expired)
        (asserts! (is-eq tx-sender (get purchaser token-data)) err-unauthorized)
        
        (ok true)
    )
)

;; Revoke access token (creator or admin only)
(define-public (revoke-access (token-id uint))
    (let (
        (token-data (unwrap! (map-get? access-tokens token-id) err-not-found))
    )
        ;; Only creator or contract owner can revoke
        (asserts! (or (is-eq tx-sender (get creator token-data)) 
                     (is-eq tx-sender contract-owner)) 
                 err-unauthorized)
        
        (map-set access-tokens token-id
            (merge token-data {is-active: false})
        )
        
        (ok true)
    )
)

;; Read-only Functions

(define-read-only (get-access-token (token-id uint))
    (ok (map-get? access-tokens token-id))
)

(define-read-only (get-user-access-token (purchaser principal) (creator principal) (content-id uint))
    (match (map-get? user-access-tokens {purchaser: purchaser, creator: creator, content-id: content-id})
        token-id (ok (map-get? access-tokens token-id))
        (ok none)
    )
)

(define-read-only (has-valid-access (purchaser principal) (creator principal) (content-id uint))
    (match (map-get? user-access-tokens {purchaser: purchaser, creator: creator, content-id: content-id})
        token-id 
            (match (map-get? access-tokens token-id)
                token-data (ok (and 
                    (get is-active token-data)
                    (<= stacks-block-height (get expiry-block token-data))
                ))
                (ok false)
            )
        (ok false)
    )
)

(define-read-only (get-transaction (transaction-id uint))
    (ok (map-get? transactions transaction-id))
)

(define-read-only (get-creator-payment-stats (creator principal))
    (ok (map-get? creator-payment-stats creator))
)

(define-read-only (get-bundle (creator principal) (bundle-id uint))
    (ok (map-get? content-bundles {creator: creator, bundle-id: bundle-id}))
)

(define-read-only (get-gift (gifter principal) (recipient principal) (gift-id uint))
    (ok (map-get? gift-access {gifter: gifter, recipient: recipient, gift-id: gift-id}))
)

(define-read-only (get-total-transactions)
    (ok (var-get total-transactions))
)

(define-read-only (get-total-volume)
    (ok (var-get total-volume))
)

(define-read-only (get-user-transaction-count (user principal))
    (ok (default-to u0 (map-get? user-transaction-count user)))
)

(define-read-only (calculate-batch-price (item-count uint) (base-price uint))
    (ok (apply-batch-discount (* base-price item-count) item-count))
)

;; Admin Functions

(define-public (set-platform-treasury (new-treasury principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set platform-treasury new-treasury)
        (ok true)
    )
)

(define-public (deactivate-bundle (creator principal) (bundle-id uint))
    (let (
        (bundle-key {creator: creator, bundle-id: bundle-id})
        (bundle-data (unwrap! (map-get? content-bundles bundle-key) err-not-found))
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        
        (map-set content-bundles bundle-key
            (merge bundle-data {is-active: false})
        )
        
        (ok true)
    )
)
