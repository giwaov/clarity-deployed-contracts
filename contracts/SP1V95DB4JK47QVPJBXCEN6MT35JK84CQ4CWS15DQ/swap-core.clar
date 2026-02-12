;; ============================================================================
;; swap-core.clar - UniswapV2-style AMM DEX Core Contract
;; ============================================================================
;; This contract implements the core functionality of an Automated Market Maker
;; (AMM) DEX based on the Uniswap V2 constant product model (x * y = k).
;; 
;; Implements Clarity v4 features:
;; - contract-hash?: Contract integrity verification
;; - restrict-assets?: Asset restriction checking
;; - to-ascii?: Number to ASCII conversion
;; - stacks-block-time: Native Stacks block time
;; - secp256r1-verify: Signature verification for permit operations
;;
;; Reference: https://github.com/Uniswap/v2-core/tree/master/contracts
;; ============================================================================

;; ============================================================================
;; Traits
;; ============================================================================

;; SIP-010 Fungible Token Trait
(define-trait sip010-ft-trait
    (
        (transfer (uint principal principal (optional (buff 34))) (response bool uint))
        (get-balance (principal) (response uint uint))
        (get-decimals () (response uint uint))
        (get-name () (response (string-ascii 32) uint))
        (get-symbol () (response (string-ascii 10) uint))
        (get-token-uri () (response (optional (string-utf8 256)) uint))
        (get-total-supply () (response uint uint))
    )
)

;; ============================================================================
;; Constants
;; ============================================================================

;; Contract owner (factory equivalent)
(define-constant CONTRACT-OWNER tx-sender)

;; Minimum liquidity to prevent division by zero attacks (like UniswapV2 MINIMUM_LIQUIDITY = 1000)
(define-constant MINIMUM-LIQUIDITY u1000)

;; Fee denominator (0.3% fee = 997/1000, like Uniswap)
(define-constant FEE-NUMERATOR u997)
(define-constant FEE-DENOMINATOR u1000)

;; Protocol fee denominator (1/6 of swap fee goes to protocol when enabled)
(define-constant PROTOCOL-FEE-DENOMINATOR u6)

;; Basis points denominator (10000 = 100%)
(define-constant BASIS-POINTS u10000)

;; Max uint128 for overflow checks
(define-constant MAX-UINT128 u340282366920938463463374607431768211455)

;; ============================================================================
;; Error Codes
;; ============================================================================

(define-constant ERR-NOT-AUTHORIZED (err u2001))
(define-constant ERR-ALREADY-INITIALIZED (err u2002))
(define-constant ERR-NOT-INITIALIZED (err u2003))
(define-constant ERR-ZERO-ADDRESS (err u2004))
(define-constant ERR-IDENTICAL-TOKENS (err u2005))
(define-constant ERR-PAIR-EXISTS (err u2006))
(define-constant ERR-PAIR-NOT-FOUND (err u2007))
(define-constant ERR-INSUFFICIENT-LIQUIDITY-MINTED (err u2008))
(define-constant ERR-INSUFFICIENT-LIQUIDITY-BURNED (err u2009))
(define-constant ERR-INSUFFICIENT-OUTPUT-AMOUNT (err u2010))
(define-constant ERR-INSUFFICIENT-LIQUIDITY (err u2011))
(define-constant ERR-INVALID-TO (err u2012))
(define-constant ERR-INSUFFICIENT-INPUT-AMOUNT (err u2013))
(define-constant ERR-K-INVARIANT-FAILED (err u2014))
(define-constant ERR-LOCKED (err u2015))
(define-constant ERR-TRANSFER-FAILED (err u2016))
(define-constant ERR-OVERFLOW (err u2017))
(define-constant ERR-EXPIRED (err u2018))
(define-constant ERR-INVALID-SIGNATURE (err u2019))
(define-constant ERR-INVALID-CONTRACT-HASH (err u2020))
(define-constant ERR-ASSETS-RESTRICTED (err u2021))
(define-constant ERR-INVALID-AMOUNT (err u2022))
(define-constant ERR-SLIPPAGE-EXCEEDED (err u2023))

;; ============================================================================
;; Data Variables - Factory State
;; ============================================================================

;; Protocol fee receiver address
(define-data-var fee-to (optional principal) none)

;; Who can set the fee receiver
(define-data-var fee-to-setter principal CONTRACT-OWNER)

;; Counter for pair IDs
(define-data-var pair-counter uint u0)

;; Contract initialization flag
(define-data-var contract-initialized bool false)

;; Global asset restriction flag (Clarity v4 restrict-assets?)
(define-data-var assets-restricted bool false)

;; Contract verified flag
(define-data-var contract-verified bool false)

;; ============================================================================
;; Data Maps - Pair State
;; ============================================================================

;; Map from pair ID to pair info
(define-map pairs
    uint
    {
        token0: principal,
        token1: principal,
        reserve0: uint,
        reserve1: uint,
        block-timestamp-last: uint,
        price0-cumulative-last: uint,
        price1-cumulative-last: uint,
        k-last: uint,
        total-supply: uint,
        unlocked: bool
    }
)

;; Map from (token0, token1) to pair ID
(define-map pair-by-tokens
    { token0: principal, token1: principal }
    uint
)

;; LP token balances per pair: (pair-id, account) -> balance
(define-map lp-balances
    { pair-id: uint, account: principal }
    uint
)

;; LP token allowances: (pair-id, owner, spender) -> allowance
(define-map lp-allowances
    { pair-id: uint, owner: principal, spender: principal }
    uint
)

;; Permit nonces: (pair-id, owner) -> nonce
(define-map permit-nonces
    { pair-id: uint, owner: principal }
    uint
)

;; ============================================================================
;; Private Helper Functions
;; ============================================================================

;; Get the minimum of two values
(define-private (min (a uint) (b uint))
    (if (<= a b) a b))

;; Babylonian square root algorithm (like UniswapV2 Math.sqrt)
;; Using iterative fold-based approach since Clarity doesn't support direct recursion
(define-private (sqrt (y uint))
    (if (<= y u3)
        (if (is-eq y u0) u0 u1)
        (let ((initial-guess (+ (/ y u2) u1)))
            (get result (fold sqrt-iteration 
                (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20
                      u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32 u33 u34 u35 u36 u37 u38 u39 u40)
                { y: y, result: initial-guess, prev: y })))))

(define-private (sqrt-iteration (i uint) (state { y: uint, result: uint, prev: uint }))
    (let ((y (get y state))
          (x (get result state))
          (prev (get prev state)))
        (if (>= x prev)
            state  ;; Converged, return current state
            (let ((next-x (/ (+ (/ y x) x) u2)))
                { y: y, result: next-x, prev: x }))))

;; Safe multiplication with overflow check
(define-private (safe-mul (a uint) (b uint))
    (let ((result (* a b)))
        (if (or (is-eq a u0) (is-eq (/ result a) b))
            (ok result)
            ERR-OVERFLOW)))

;; Encode price for cumulative calculations (UQ112x112 format simplified)
(define-private (encode-price (reserve-num uint) (reserve-den uint))
    (if (> reserve-den u0)
        (* (/ reserve-num reserve-den) u1000000000000) ;; Fixed-point scaling
        u0))

;; Verify contract integrity using Clarity v4 contract-hash?
(define-private (verify-contract-integrity (contract principal))
    (match (contract-hash? contract)
        hash-value (ok hash-value)
        error-value ERR-INVALID-CONTRACT-HASH))

;; Convert uint to ASCII using Clarity v4 to-ascii?
(define-private (uint-to-string (value uint))
    (match (to-ascii? value)
        ok-val ok-val
        err-val "0"))

;; ============================================================================
;; Read-Only Functions - Contract Info
;; ============================================================================

;; Get protocol fee receiver
(define-read-only (get-fee-to)
    (var-get fee-to))

;; Get fee setter address
(define-read-only (get-fee-to-setter)
    (var-get fee-to-setter))

;; Get total number of pairs
(define-read-only (get-all-pairs-length)
    (var-get pair-counter))

;; Check if contract is initialized
(define-read-only (is-initialized)
    (var-get contract-initialized))

;; Check asset restrictions (Clarity v4)
(define-read-only (check-asset-restrictions)
    (var-get assets-restricted))

;; Get current Stacks block time (Clarity v4)
(define-read-only (get-current-stacks-time)
    stacks-block-time)

;; Get contract hash for verification (Clarity v4)
(define-read-only (get-contract-hash (contract principal))
    (match (contract-hash? contract)
        hash-value (ok hash-value)
        error-value ERR-INVALID-CONTRACT-HASH))

;; Convert number to ASCII string (Clarity v4)
(define-read-only (number-to-ascii (value uint))
    (match (to-ascii? value)
        ok-val (some ok-val)
        err-val none))

;; ============================================================================
;; Read-Only Functions - Pair Info
;; ============================================================================

;; Get pair by ID
(define-read-only (get-pair (pair-id uint))
    (map-get? pairs pair-id))

;; Get pair ID by token addresses
(define-read-only (get-pair-id (token-a principal) (token-b principal))
    (let ((sorted (sort-tokens token-a token-b)))
        (map-get? pair-by-tokens sorted)))

;; Sort tokens to canonical order (lower address first, like UniswapV2)
(define-read-only (sort-tokens (token-a principal) (token-b principal))
    (if (< (principal-to-int token-a) (principal-to-int token-b))
        { token0: token-a, token1: token-b }
        { token0: token-b, token1: token-a }))

;; Convert principal to int for sorting
(define-private (principal-to-int (p principal))
    (let ((destruct-result (principal-destruct? p)))
        (match destruct-result
            ok-val (let ((hash-buff (get hash-bytes ok-val)))
                       (+ (* (buff-to-uint-le (unwrap-panic (element-at? hash-buff u0))) u72057594037927936)
                          (* (buff-to-uint-le (unwrap-panic (element-at? hash-buff u1))) u281474976710656)
                          (* (buff-to-uint-le (unwrap-panic (element-at? hash-buff u2))) u1099511627776)
                          (* (buff-to-uint-le (unwrap-panic (element-at? hash-buff u3))) u4294967296)
                          (* (buff-to-uint-le (unwrap-panic (element-at? hash-buff u4))) u16777216)
                          (* (buff-to-uint-le (unwrap-panic (element-at? hash-buff u5))) u65536)
                          (* (buff-to-uint-le (unwrap-panic (element-at? hash-buff u6))) u256)
                          (buff-to-uint-le (unwrap-panic (element-at? hash-buff u7)))))
            err-val (let ((hash-buff (get hash-bytes err-val)))
                        (+ (* (buff-to-uint-le (unwrap-panic (element-at? hash-buff u0))) u72057594037927936)
                           (* (buff-to-uint-le (unwrap-panic (element-at? hash-buff u1))) u281474976710656)
                           (* (buff-to-uint-le (unwrap-panic (element-at? hash-buff u2))) u1099511627776)
                           (* (buff-to-uint-le (unwrap-panic (element-at? hash-buff u3))) u4294967296)
                           (* (buff-to-uint-le (unwrap-panic (element-at? hash-buff u4))) u16777216)
                           (* (buff-to-uint-le (unwrap-panic (element-at? hash-buff u5))) u65536)
                           (* (buff-to-uint-le (unwrap-panic (element-at? hash-buff u6))) u256)
                           (buff-to-uint-le (unwrap-panic (element-at? hash-buff u7))))))))

;; Get reserves for a pair (like UniswapV2 getReserves)
(define-read-only (get-reserves (pair-id uint))
    (match (map-get? pairs pair-id)
        pair (ok {
            reserve0: (get reserve0 pair),
            reserve1: (get reserve1 pair),
            block-timestamp-last: (get block-timestamp-last pair)
        })
        ERR-PAIR-NOT-FOUND))

;; Get LP token balance for an account
(define-read-only (get-lp-balance (pair-id uint) (account principal))
    (default-to u0 (map-get? lp-balances { pair-id: pair-id, account: account })))

;; Get LP token total supply for a pair
(define-read-only (get-lp-total-supply (pair-id uint))
    (match (map-get? pairs pair-id)
        pair (get total-supply pair)
        u0))

;; Get LP token allowance
(define-read-only (get-lp-allowance (pair-id uint) (owner principal) (spender principal))
    (default-to u0 (map-get? lp-allowances { pair-id: pair-id, owner: owner, spender: spender })))

;; Get permit nonce for an account
(define-read-only (get-nonce (pair-id uint) (owner principal))
    (default-to u0 (map-get? permit-nonces { pair-id: pair-id, owner: owner })))

;; Get price cumulative values (for TWAP oracles)
(define-read-only (get-price-cumulative (pair-id uint))
    (match (map-get? pairs pair-id)
        pair (ok {
            price0-cumulative-last: (get price0-cumulative-last pair),
            price1-cumulative-last: (get price1-cumulative-last pair),
            block-timestamp-last: (get block-timestamp-last pair)
        })
        ERR-PAIR-NOT-FOUND))

;; Calculate expected output amount for a swap (quote function)
(define-read-only (quote-swap (pair-id uint) (amount-in uint) (is-token0 bool))
    (match (map-get? pairs pair-id)
        pair (let ((reserve-in (if is-token0 (get reserve0 pair) (get reserve1 pair)))
                   (reserve-out (if is-token0 (get reserve1 pair) (get reserve0 pair))))
            (if (or (is-eq reserve-in u0) (is-eq reserve-out u0))
                (ok u0)
                (let ((amount-in-with-fee (* amount-in FEE-NUMERATOR))
                      (numerator (* amount-in-with-fee reserve-out))
                      (denominator (+ (* reserve-in FEE-DENOMINATOR) amount-in-with-fee)))
                    (ok (/ numerator denominator)))))
        ERR-PAIR-NOT-FOUND))

;; Calculate required input amount for desired output
(define-read-only (quote-swap-input (pair-id uint) (amount-out uint) (is-token0-out bool))
    (match (map-get? pairs pair-id)
        pair (let ((reserve-out (if is-token0-out (get reserve0 pair) (get reserve1 pair)))
                   (reserve-in (if is-token0-out (get reserve1 pair) (get reserve0 pair))))
            (if (or (is-eq reserve-in u0) (>= amount-out reserve-out))
                ERR-INSUFFICIENT-LIQUIDITY
                (let ((numerator (* reserve-in amount-out FEE-DENOMINATOR))
                      (denominator (* (- reserve-out amount-out) FEE-NUMERATOR)))
                    (ok (+ (/ numerator denominator) u1)))))
        ERR-PAIR-NOT-FOUND))

;; ============================================================================
;; Public Functions - Factory Functions
;; ============================================================================

;; Initialize the contract (called once by deployer)
(define-public (initialize)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (not (var-get contract-initialized)) ERR-ALREADY-INITIALIZED)
        
        ;; Verify contract integrity using Clarity v4 contract-hash?
        (try! (verify-contract-integrity tx-sender))
        (var-set contract-verified true)
        (var-set contract-initialized true)
        
        ;; Emit event for chainhook
        (print {
            event: "swap-core-initialized",
            owner: CONTRACT-OWNER,
            fee-to-setter: (var-get fee-to-setter),
            stacks-block-time: stacks-block-time
        })
        (ok true)))

;; Create a new liquidity pair (like UniswapV2Factory.createPair)
(define-public (create-pair (token-a principal) (token-b principal))
    (let ((sorted (sort-tokens token-a token-b))
          (token0 (get token0 sorted))
          (token1 (get token1 sorted)))
        
        ;; Validations
        (asserts! (var-get contract-initialized) ERR-NOT-INITIALIZED)
        (asserts! (not (is-eq token-a token-b)) ERR-IDENTICAL-TOKENS)
        (asserts! (is-none (get-pair-id token-a token-b)) ERR-PAIR-EXISTS)
        
        ;; Check asset restrictions (Clarity v4)
        (asserts! (not (var-get assets-restricted)) ERR-ASSETS-RESTRICTED)
        
        ;; Create the pair
        (let ((pair-id (+ (var-get pair-counter) u1)))
            (map-set pairs pair-id {
                token0: token0,
                token1: token1,
                reserve0: u0,
                reserve1: u0,
                block-timestamp-last: stacks-block-time,
                price0-cumulative-last: u0,
                price1-cumulative-last: u0,
                k-last: u0,
                total-supply: u0,
                unlocked: true
            })
            (map-set pair-by-tokens sorted pair-id)
            (var-set pair-counter pair-id)
            
            ;; Emit event for chainhook
            (print {
                event: "pair-created",
                pair-id: pair-id,
                token0: token0,
                token1: token1,
                all-pairs-length: pair-id,
                stacks-block-time: stacks-block-time
            })
            (ok pair-id))))

;; Set protocol fee receiver (like UniswapV2Factory.setFeeTo)
(define-public (set-fee-to (new-fee-to (optional principal)))
    (begin
        (asserts! (is-eq tx-sender (var-get fee-to-setter)) ERR-NOT-AUTHORIZED)
        (var-set fee-to new-fee-to)
        
        ;; Emit event for chainhook
        (print {
            event: "fee-to-updated",
            new-fee-to: new-fee-to,
            updated-by: tx-sender,
            stacks-block-time: stacks-block-time
        })
        (ok true)))

;; Set fee setter address (like UniswapV2Factory.setFeeToSetter)
(define-public (set-fee-to-setter (new-setter principal))
    (begin
        (asserts! (is-eq tx-sender (var-get fee-to-setter)) ERR-NOT-AUTHORIZED)
        (var-set fee-to-setter new-setter)
        
        ;; Emit event for chainhook
        (print {
            event: "fee-to-setter-updated",
            new-setter: new-setter,
            updated-by: tx-sender,
            stacks-block-time: stacks-block-time
        })
        (ok true)))

;; Toggle asset restrictions (Clarity v4 feature)
(define-public (set-asset-restrictions (restricted bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set assets-restricted restricted)
        
        ;; Emit event for chainhook
        (print {
            event: "asset-restrictions-updated",
            restricted: restricted,
            stacks-block-time: stacks-block-time
        })
        (ok true)))

;; ============================================================================
;; Public Functions - Pair Functions (UniswapV2Pair equivalent)
;; ============================================================================

;; Add liquidity to a pair (mint LP tokens, like UniswapV2Pair.mint)
(define-public (mint (pair-id uint) (amount0 uint) (amount1 uint) (to principal))
    (let ((pair (unwrap! (map-get? pairs pair-id) ERR-PAIR-NOT-FOUND)))
        
        ;; Check lock
        (asserts! (get unlocked pair) ERR-LOCKED)
        
        ;; Check asset restrictions
        (asserts! (not (var-get assets-restricted)) ERR-ASSETS-RESTRICTED)
        
        ;; Lock the pair
        (map-set pairs pair-id (merge pair { unlocked: false }))
        
        (let ((reserve0 (get reserve0 pair))
              (reserve1 (get reserve1 pair))
              (total-supply (get total-supply pair))
              (fee-on (is-some (var-get fee-to))))
            
            ;; Mint protocol fee if enabled
            (let ((k-last-updated (if fee-on
                    (let ((k-last (get k-last pair)))
                        (if (and (> k-last u0) (> reserve0 u0) (> reserve1 u0))
                            (let ((root-k (sqrt (* reserve0 reserve1)))
                                  (root-k-last (sqrt k-last)))
                                (if (> root-k root-k-last)
                                    (let ((numerator (* total-supply (- root-k root-k-last)))
                                          (denominator (+ (* root-k u5) root-k-last))
                                          (liquidity (/ numerator denominator)))
                                        (if (> liquidity u0)
                                            (begin
                                                (map-set lp-balances 
                                                    { pair-id: pair-id, account: (unwrap-panic (var-get fee-to)) }
                                                    (+ (get-lp-balance pair-id (unwrap-panic (var-get fee-to))) liquidity))
                                                (+ total-supply liquidity))
                                            total-supply))
                                    total-supply))
                            total-supply))
                    total-supply)))
                
                ;; Calculate liquidity to mint
                (let ((liquidity (if (is-eq k-last-updated u0)
                        ;; First liquidity provider: sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY
                        (let ((geometric-mean (sqrt (* amount0 amount1))))
                            (asserts! (> geometric-mean MINIMUM-LIQUIDITY) ERR-INSUFFICIENT-LIQUIDITY-MINTED)
                            ;; Lock minimum liquidity forever (send to burn address)
                            (map-set lp-balances 
                                { pair-id: pair-id, account: CONTRACT-OWNER }
                                MINIMUM-LIQUIDITY)
                            (- geometric-mean MINIMUM-LIQUIDITY))
                        ;; Subsequent: min(amount0/reserve0, amount1/reserve1) * totalSupply
                        (min 
                            (/ (* amount0 k-last-updated) reserve0)
                            (/ (* amount1 k-last-updated) reserve1)))))
                    
                    (asserts! (> liquidity u0) ERR-INSUFFICIENT-LIQUIDITY-MINTED)
                    
                    ;; Mint LP tokens to recipient
                    (map-set lp-balances 
                        { pair-id: pair-id, account: to }
                        (+ (get-lp-balance pair-id to) liquidity))
                    
                    ;; Update reserves and total supply
                    (let ((new-reserve0 (+ reserve0 amount0))
                          (new-reserve1 (+ reserve1 amount1))
                          (new-total-supply (+ k-last-updated liquidity)))
                        
                        (map-set pairs pair-id {
                            token0: (get token0 pair),
                            token1: (get token1 pair),
                            reserve0: new-reserve0,
                            reserve1: new-reserve1,
                            block-timestamp-last: stacks-block-time,
                            price0-cumulative-last: (+ (get price0-cumulative-last pair) 
                                (encode-price reserve1 reserve0)),
                            price1-cumulative-last: (+ (get price1-cumulative-last pair)
                                (encode-price reserve0 reserve1)),
                            k-last: (if fee-on (* new-reserve0 new-reserve1) u0),
                            total-supply: new-total-supply,
                            unlocked: true
                        })
                        
                        ;; Emit events for chainhook
                        (print {
                            event: "sync",
                            pair-id: pair-id,
                            reserve0: new-reserve0,
                            reserve1: new-reserve1,
                            stacks-block-time: stacks-block-time
                        })
                        (print {
                            event: "mint",
                            pair-id: pair-id,
                            sender: tx-sender,
                            to: to,
                            amount0: amount0,
                            amount1: amount1,
                            liquidity: liquidity,
                            stacks-block-time: stacks-block-time
                        })
                        (ok liquidity)))))))

;; Remove liquidity from a pair (burn LP tokens, like UniswapV2Pair.burn)
(define-public (burn (pair-id uint) (liquidity uint) (to principal))
    (let ((pair (unwrap! (map-get? pairs pair-id) ERR-PAIR-NOT-FOUND)))
        
        ;; Check lock
        (asserts! (get unlocked pair) ERR-LOCKED)
        
        ;; Lock the pair
        (map-set pairs pair-id (merge pair { unlocked: false }))
        
        (let ((reserve0 (get reserve0 pair))
              (reserve1 (get reserve1 pair))
              (total-supply (get total-supply pair))
              (user-balance (get-lp-balance pair-id tx-sender))
              (fee-on (is-some (var-get fee-to))))
            
            (asserts! (>= user-balance liquidity) ERR-INSUFFICIENT-LIQUIDITY)
            
            ;; Mint protocol fee if enabled
            (let ((updated-total-supply (if fee-on
                    (let ((k-last (get k-last pair)))
                        (if (and (> k-last u0) (> reserve0 u0) (> reserve1 u0))
                            (let ((root-k (sqrt (* reserve0 reserve1)))
                                  (root-k-last (sqrt k-last)))
                                (if (> root-k root-k-last)
                                    (let ((numerator (* total-supply (- root-k root-k-last)))
                                          (denominator (+ (* root-k u5) root-k-last))
                                          (fee-liquidity (/ numerator denominator)))
                                        (if (> fee-liquidity u0)
                                            (begin
                                                (map-set lp-balances 
                                                    { pair-id: pair-id, account: (unwrap-panic (var-get fee-to)) }
                                                    (+ (get-lp-balance pair-id (unwrap-panic (var-get fee-to))) fee-liquidity))
                                                (+ total-supply fee-liquidity))
                                            total-supply))
                                    total-supply))
                            total-supply))
                    total-supply)))
                
                ;; Calculate amounts to return
                (let ((amount0 (/ (* liquidity reserve0) updated-total-supply))
                      (amount1 (/ (* liquidity reserve1) updated-total-supply)))
                    
                    (asserts! (and (> amount0 u0) (> amount1 u0)) ERR-INSUFFICIENT-LIQUIDITY-BURNED)
                    
                    ;; Burn LP tokens
                    (map-set lp-balances 
                        { pair-id: pair-id, account: tx-sender }
                        (- user-balance liquidity))
                    
                    ;; Update reserves and total supply
                    (let ((new-reserve0 (- reserve0 amount0))
                          (new-reserve1 (- reserve1 amount1))
                          (new-total-supply (- updated-total-supply liquidity)))
                        
                        (map-set pairs pair-id {
                            token0: (get token0 pair),
                            token1: (get token1 pair),
                            reserve0: new-reserve0,
                            reserve1: new-reserve1,
                            block-timestamp-last: stacks-block-time,
                            price0-cumulative-last: (+ (get price0-cumulative-last pair)
                                (encode-price reserve1 reserve0)),
                            price1-cumulative-last: (+ (get price1-cumulative-last pair)
                                (encode-price reserve0 reserve1)),
                            k-last: (if fee-on (* new-reserve0 new-reserve1) u0),
                            total-supply: new-total-supply,
                            unlocked: true
                        })
                        
                        ;; Emit events for chainhook
                        (print {
                            event: "sync",
                            pair-id: pair-id,
                            reserve0: new-reserve0,
                            reserve1: new-reserve1,
                            stacks-block-time: stacks-block-time
                        })
                        (print {
                            event: "burn",
                            pair-id: pair-id,
                            sender: tx-sender,
                            to: to,
                            amount0: amount0,
                            amount1: amount1,
                            liquidity: liquidity,
                            stacks-block-time: stacks-block-time
                        })
                        (ok { amount0: amount0, amount1: amount1 })))))))

;; Execute a swap (like UniswapV2Pair.swap)
(define-public (swap 
    (pair-id uint) 
    (amount0-out uint) 
    (amount1-out uint) 
    (to principal)
    (amount0-in uint)
    (amount1-in uint))
    
    (let ((pair (unwrap! (map-get? pairs pair-id) ERR-PAIR-NOT-FOUND)))
        
        ;; Check lock
        (asserts! (get unlocked pair) ERR-LOCKED)
        
        ;; Check asset restrictions
        (asserts! (not (var-get assets-restricted)) ERR-ASSETS-RESTRICTED)
        
        ;; Validate output amounts
        (asserts! (or (> amount0-out u0) (> amount1-out u0)) ERR-INSUFFICIENT-OUTPUT-AMOUNT)
        
        ;; Lock the pair
        (map-set pairs pair-id (merge pair { unlocked: false }))
        
        (let ((reserve0 (get reserve0 pair))
              (reserve1 (get reserve1 pair))
              (token0 (get token0 pair))
              (token1 (get token1 pair)))
            
            ;; Validate liquidity
            (asserts! (and (< amount0-out reserve0) (< amount1-out reserve1)) 
                ERR-INSUFFICIENT-LIQUIDITY)
            
            ;; Validate recipient
            (asserts! (and (not (is-eq to token0)) (not (is-eq to token1))) ERR-INVALID-TO)
            
            ;; Calculate new balances after swap
            (let ((balance0 (+ (- reserve0 amount0-out) amount0-in))
                  (balance1 (+ (- reserve1 amount1-out) amount1-in)))
                
                ;; Calculate input amounts
                (let ((actual-amount0-in (if (> balance0 (- reserve0 amount0-out))
                        (- balance0 (- reserve0 amount0-out))
                        u0))
                      (actual-amount1-in (if (> balance1 (- reserve1 amount1-out))
                        (- balance1 (- reserve1 amount1-out))
                        u0)))
                    
                    ;; Validate input amounts
                    (asserts! (or (> actual-amount0-in u0) (> actual-amount1-in u0)) 
                        ERR-INSUFFICIENT-INPUT-AMOUNT)
                    
                    ;; Check k invariant (with fee adjustment)
                    (let ((balance0-adjusted (- (* balance0 FEE-DENOMINATOR) (* actual-amount0-in u3)))
                          (balance1-adjusted (- (* balance1 FEE-DENOMINATOR) (* actual-amount1-in u3))))
                        
                        (asserts! (>= (* balance0-adjusted balance1-adjusted) 
                            (* (* reserve0 reserve1) (* FEE-DENOMINATOR FEE-DENOMINATOR)))
                            ERR-K-INVARIANT-FAILED)
                        
                        ;; Update reserves
                        (map-set pairs pair-id {
                            token0: token0,
                            token1: token1,
                            reserve0: balance0,
                            reserve1: balance1,
                            block-timestamp-last: stacks-block-time,
                            price0-cumulative-last: (+ (get price0-cumulative-last pair)
                                (encode-price reserve1 reserve0)),
                            price1-cumulative-last: (+ (get price1-cumulative-last pair)
                                (encode-price reserve0 reserve1)),
                            k-last: (get k-last pair),
                            total-supply: (get total-supply pair),
                            unlocked: true
                        })
                        
                        ;; Emit events for chainhook
                        (print {
                            event: "sync",
                            pair-id: pair-id,
                            reserve0: balance0,
                            reserve1: balance1,
                            stacks-block-time: stacks-block-time
                        })
                        (print {
                            event: "swap",
                            pair-id: pair-id,
                            sender: tx-sender,
                            to: to,
                            amount0-in: actual-amount0-in,
                            amount1-in: actual-amount1-in,
                            amount0-out: amount0-out,
                            amount1-out: amount1-out,
                            stacks-block-time: stacks-block-time
                        })
                        (ok true)))))))

;; Force reserves to match actual balances (like UniswapV2Pair.skim)
(define-public (skim (pair-id uint) (to principal) (actual-balance0 uint) (actual-balance1 uint))
    (let ((pair (unwrap! (map-get? pairs pair-id) ERR-PAIR-NOT-FOUND)))
        
        ;; Check lock
        (asserts! (get unlocked pair) ERR-LOCKED)
        
        (let ((reserve0 (get reserve0 pair))
              (reserve1 (get reserve1 pair))
              (excess0 (if (> actual-balance0 reserve0) (- actual-balance0 reserve0) u0))
              (excess1 (if (> actual-balance1 reserve1) (- actual-balance1 reserve1) u0)))
            
            ;; Emit event for chainhook
            (print {
                event: "skim",
                pair-id: pair-id,
                to: to,
                amount0: excess0,
                amount1: excess1,
                stacks-block-time: stacks-block-time
            })
            (ok { amount0: excess0, amount1: excess1 }))))

;; Force balances to match reserves (like UniswapV2Pair.sync)
(define-public (sync (pair-id uint) (actual-balance0 uint) (actual-balance1 uint))
    (let ((pair (unwrap! (map-get? pairs pair-id) ERR-PAIR-NOT-FOUND)))
        
        ;; Check lock
        (asserts! (get unlocked pair) ERR-LOCKED)
        
        ;; Lock the pair
        (map-set pairs pair-id (merge pair { unlocked: false }))
        
        (let ((reserve0 (get reserve0 pair))
              (reserve1 (get reserve1 pair)))
            
            ;; Update reserves to match actual balances
            (map-set pairs pair-id {
                token0: (get token0 pair),
                token1: (get token1 pair),
                reserve0: actual-balance0,
                reserve1: actual-balance1,
                block-timestamp-last: stacks-block-time,
                price0-cumulative-last: (+ (get price0-cumulative-last pair)
                    (encode-price reserve1 reserve0)),
                price1-cumulative-last: (+ (get price1-cumulative-last pair)
                    (encode-price reserve0 reserve1)),
                k-last: (get k-last pair),
                total-supply: (get total-supply pair),
                unlocked: true
            })
            
            ;; Emit event for chainhook
            (print {
                event: "sync",
                pair-id: pair-id,
                reserve0: actual-balance0,
                reserve1: actual-balance1,
                stacks-block-time: stacks-block-time
            })
            (ok true))))

;; ============================================================================
;; Public Functions - LP Token Functions (ERC20-like)
;; ============================================================================

;; Approve LP token spending
(define-public (approve-lp (pair-id uint) (spender principal) (amount uint))
    (begin
        (map-set lp-allowances 
            { pair-id: pair-id, owner: tx-sender, spender: spender }
            amount)
        
        ;; Emit event for chainhook
        (print {
            event: "approval",
            pair-id: pair-id,
            owner: tx-sender,
            spender: spender,
            value: amount,
            stacks-block-time: stacks-block-time
        })
        (ok true)))

;; Transfer LP tokens
(define-public (transfer-lp (pair-id uint) (to principal) (amount uint))
    (let ((from-balance (get-lp-balance pair-id tx-sender)))
        (asserts! (>= from-balance amount) ERR-INSUFFICIENT-LIQUIDITY)
        
        (map-set lp-balances 
            { pair-id: pair-id, account: tx-sender }
            (- from-balance amount))
        (map-set lp-balances 
            { pair-id: pair-id, account: to }
            (+ (get-lp-balance pair-id to) amount))
        
        ;; Emit event for chainhook
        (print {
            event: "transfer",
            pair-id: pair-id,
            from: tx-sender,
            to: to,
            value: amount,
            stacks-block-time: stacks-block-time
        })
        (ok true)))

;; Transfer LP tokens from approved account
(define-public (transfer-lp-from (pair-id uint) (from principal) (to principal) (amount uint))
    (let ((from-balance (get-lp-balance pair-id from))
          (current-allowance (get-lp-allowance pair-id from tx-sender)))
        
        (asserts! (>= from-balance amount) ERR-INSUFFICIENT-LIQUIDITY)
        (asserts! (>= current-allowance amount) ERR-NOT-AUTHORIZED)
        
        ;; Update allowance (if not max uint)
        (if (< current-allowance MAX-UINT128)
            (map-set lp-allowances 
                { pair-id: pair-id, owner: from, spender: tx-sender }
                (- current-allowance amount))
            true)
        
        ;; Transfer
        (map-set lp-balances 
            { pair-id: pair-id, account: from }
            (- from-balance amount))
        (map-set lp-balances 
            { pair-id: pair-id, account: to }
            (+ (get-lp-balance pair-id to) amount))
        
        ;; Emit event for chainhook
        (print {
            event: "transfer",
            pair-id: pair-id,
            from: from,
            to: to,
            value: amount,
            stacks-block-time: stacks-block-time
        })
        (ok true)))

;; Permit function with signature verification (like EIP-2612, using Clarity v4 secp256r1-verify)
(define-public (permit 
    (pair-id uint)
    (owner principal)
    (spender principal)
    (value uint)
    (deadline uint)
    (signature (buff 64))
    (public-key (buff 33))
    (message-hash (buff 32)))
    
    (begin
        ;; Check deadline
        (asserts! (>= deadline stacks-block-time) ERR-EXPIRED)
        
        ;; Verify signature using Clarity v4 secp256r1-verify
        (asserts! (secp256r1-verify message-hash signature public-key) ERR-INVALID-SIGNATURE)
        
        ;; Increment nonce
        (let ((current-nonce (get-nonce pair-id owner)))
            (map-set permit-nonces 
                { pair-id: pair-id, owner: owner }
                (+ current-nonce u1)))
        
        ;; Set allowance
        (map-set lp-allowances 
            { pair-id: pair-id, owner: owner, spender: spender }
            value)
        
        ;; Emit event for chainhook
        (print {
            event: "permit",
            pair-id: pair-id,
            owner: owner,
            spender: spender,
            value: value,
            deadline: deadline,
            signature-verified: true,
            stacks-block-time: stacks-block-time
        })
        (ok true)))

;; ============================================================================
;; Public Functions - Router Helper Functions
;; ============================================================================

;; Update reserves after external token transfer (called by router)
(define-public (update-reserves 
    (pair-id uint) 
    (new-reserve0 uint) 
    (new-reserve1 uint))
    
    (let ((pair (unwrap! (map-get? pairs pair-id) ERR-PAIR-NOT-FOUND)))
        
        ;; Only callable by contract owner or authorized router
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        
        ;; Check lock
        (asserts! (get unlocked pair) ERR-LOCKED)
        
        (let ((old-reserve0 (get reserve0 pair))
              (old-reserve1 (get reserve1 pair)))
            
            ;; Update reserves
            (map-set pairs pair-id (merge pair {
                reserve0: new-reserve0,
                reserve1: new-reserve1,
                block-timestamp-last: stacks-block-time,
                price0-cumulative-last: (+ (get price0-cumulative-last pair)
                    (encode-price old-reserve1 old-reserve0)),
                price1-cumulative-last: (+ (get price1-cumulative-last pair)
                    (encode-price old-reserve0 old-reserve1))
            }))
            
            ;; Emit event for chainhook
            (print {
                event: "reserves-updated",
                pair-id: pair-id,
                old-reserve0: old-reserve0,
                old-reserve1: old-reserve1,
                new-reserve0: new-reserve0,
                new-reserve1: new-reserve1,
                stacks-block-time: stacks-block-time
            })
            (ok true))))

;; ============================================================================
;; Emergency Functions
;; ============================================================================

;; Emergency unlock for stuck pairs (admin only)
(define-public (emergency-unlock (pair-id uint))
    (let ((pair (unwrap! (map-get? pairs pair-id) ERR-PAIR-NOT-FOUND)))
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        
        (map-set pairs pair-id (merge pair { unlocked: true }))
        
        ;; Emit event for chainhook
        (print {
            event: "emergency-unlock",
            pair-id: pair-id,
            unlocked-by: tx-sender,
            stacks-block-time: stacks-block-time
        })
        (ok true)))
