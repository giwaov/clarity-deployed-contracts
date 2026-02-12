
;; title: sBTC-BitDeriv
;; version:
;; summary:
;; description:

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-EXPIRED (err u1))
(define-constant ERR-INVALID-AMOUNT (err u2))
(define-constant ERR-UNAUTHORIZED (err u3))
(define-constant ERR-NOT-FOUND (err u4))
(define-constant ERR-INSUFFICIENT-BALANCE (err u5))
(define-constant ERR-ALREADY-EXECUTED (err u6))
(define-constant ERR-INVALID-PRICE (err u7))
(define-constant ERR-OPTION-NOT-ACTIVE (err u8))
(define-constant ERR-INVALID-SIGNATURE (err u9))

;; Option Types
(define-constant CALL u1)
(define-constant PUT u2)

;; Data Maps
(define-map BTCBalances
    { holder: principal }
    { balance: uint }
)

;; Escrow map to track BTC locked in options
(define-map EscrowedBTC
    { option-id: uint }
    { amount: uint }
)

(define-map Options
    { option-id: uint }
    {
        creator: principal,
        buyer: (optional principal),
        option-type: uint,
        strike-price: uint,
        premium: uint,
        expiry: uint,
        btc-amount: uint,
        is-active: bool,
        is-executed: bool,
        creation-time: uint
    }
)

(define-map UserOptions
    { user: principal }
    { created: (list 20 uint), purchased: (list 20 uint) }
)

;; Data Variables
(define-data-var next-option-id uint u0)
(define-data-var oracle-price uint u0)
(define-data-var oracle-public-key (buff 33) 0x000000000000000000000000000000000000000000000000000000000000000000)

;; Authorization
(define-private (is-contract-owner)
    (is-eq tx-sender CONTRACT-OWNER)
)

;; BTC Balance Management
(define-public (deposit-btc (amount uint))
    (let
        ((sender tx-sender)
         (current-balance (default-to { balance: u0 } (map-get? BTCBalances { holder: sender }))))
        (map-set BTCBalances
            { holder: sender }
            { balance: (+ amount (get balance current-balance)) })
        (ok true)
    )
)

(define-public (withdraw-btc (amount uint))
    (let
        ((sender tx-sender)
         (current-balance (default-to { balance: u0 } (map-get? BTCBalances { holder: sender }))))
        (asserts! (>= (get balance current-balance) amount) ERR-INSUFFICIENT-BALANCE)
        (map-set BTCBalances
            { holder: sender }
            { balance: (- (get balance current-balance) amount) })
        (ok true)
    )
)

(define-private (transfer-btc (from principal) (to principal) (amount uint))
    (let
        ((from-balance (default-to { balance: u0 } (map-get? BTCBalances { holder: from })))
         (to-balance (default-to { balance: u0 } (map-get? BTCBalances { holder: to }))))
        (asserts! (>= (get balance from-balance) amount) ERR-INSUFFICIENT-BALANCE)
        (map-set BTCBalances
            { holder: from }
            { balance: (- (get balance from-balance) amount) })
        (map-set BTCBalances
            { holder: to }
            { balance: (+ amount (get balance to-balance)) })
        (ok true)
    )
)

(define-private (update-user-options (user principal) (option-id uint) (is-creator bool))
    (let
        ((user-options (default-to 
            { created: (list ), purchased: (list ) }
            (map-get? UserOptions { user: user }))))
        (if is-creator
            (ok (map-set UserOptions
                { user: user }
                { created: (unwrap! (as-max-len? (append (get created user-options) option-id) u20) ERR-UNAUTHORIZED),
                  purchased: (get purchased user-options) }))
            (ok (map-set UserOptions
                { user: user }
                { created: (get created user-options),
                  purchased: (unwrap! (as-max-len? (append (get purchased user-options) option-id) u20) ERR-UNAUTHORIZED) })))
    )
)




;; Option Management
(define-public (create-option
    (option-type uint)
    (strike-price uint)
    (premium uint)
    (expiry uint)
    (btc-amount uint))
    (let
        ((option-id (+ (var-get next-option-id) u1))
         (sender tx-sender)
         (current-balance (default-to { balance: u0 } (map-get? BTCBalances { holder: sender }))))

        ;; Validate inputs
        (asserts! (or (is-eq option-type CALL) (is-eq option-type PUT)) ERR-INVALID-AMOUNT)
        (asserts! (> strike-price u0) ERR-INVALID-PRICE)
        (asserts! (> premium u0) ERR-INVALID-PRICE)
        (asserts! (> expiry stacks-block-time) ERR-EXPIRED)
        (asserts! (> btc-amount u0) ERR-INVALID-AMOUNT)

        ;; For CALL options, ensure creator has enough BTC
        (asserts! (if (is-eq option-type CALL)
            (>= (get balance current-balance) btc-amount)
            true) ERR-INSUFFICIENT-BALANCE)

        ;; Create option
        (map-set Options
            { option-id: option-id }
            {
                creator: sender,
                buyer: none,
                option-type: option-type,
                strike-price: strike-price,
                premium: premium,
                expiry: expiry,
                btc-amount: btc-amount,
                is-active: true,
                is-executed: false,
                creation-time: stacks-block-time
            })

        ;; Lock BTC for CALL options by reducing creator's balance and tracking in escrow
        (if (is-eq option-type CALL)
            (begin
                ;; Deduct BTC from creator's balance
                (map-set BTCBalances
                    { holder: sender }
                    { balance: (- (get balance current-balance) btc-amount) })
                ;; Add to escrow
                (map-set EscrowedBTC
                    { option-id: option-id }
                    { amount: btc-amount }))
            true)

        ;; Update state
        (var-set next-option-id option-id)
        (try! (update-user-options sender option-id true))
        (ok option-id)
    )
)



;; Private helper functions
(define-private (exercise-call
    (option-id uint)
    (option {
        creator: principal,
        buyer: (optional principal),
        option-type: uint,
        strike-price: uint,
        premium: uint,
        expiry: uint,
        btc-amount: uint,
        is-active: bool,
        is-executed: bool,
        creation-time: uint
    })
    (holder principal))
    (let
        ((strike-amount (* (get strike-price option) (get btc-amount option)))
         (holder-balance (default-to { balance: u0 } (map-get? BTCBalances { holder: holder }))))
        ;; Transfer strike price from holder to creator
        (try! (stx-transfer? strike-amount holder (get creator option)))
        ;; Transfer escrowed BTC to holder
        (map-set BTCBalances
            { holder: holder }
            { balance: (+ (get balance holder-balance) (get btc-amount option)) })
        ;; Remove from escrow
        (map-delete EscrowedBTC { option-id: option-id })
        (ok true)
    )
)





(define-public (exercise-option (option-id uint))
    (let
        ((option (unwrap! (map-get? Options { option-id: option-id }) ERR-NOT-FOUND))
         (holder tx-sender))

        ;; Validate option state
        (asserts! (is-eq (some holder) (get buyer option)) ERR-UNAUTHORIZED)
        (asserts! (not (get is-executed option)) ERR-ALREADY-EXECUTED)
        (asserts! (< stacks-block-time (get expiry option)) ERR-EXPIRED)

        ;; Exercise based on option type
        (if (is-eq (get option-type option) CALL)
            (try! (exercise-call option-id option holder))
            (try! (exercise-put option-id option holder)))

        ;; Update option state
        (map-set Options
            { option-id: option-id }
            (merge option { is-executed: true }))
        (ok true)
    )
)

(define-private (exercise-put
    (option-id uint)
    (option {
        creator: principal,
        buyer: (optional principal),
        option-type: uint,
        strike-price: uint,
        premium: uint,
        expiry: uint,
        btc-amount: uint,
        is-active: bool,
        is-executed: bool,
        creation-time: uint
    })
    (holder principal))
    (let
        ((strike-amount (* (get strike-price option) (get btc-amount option)))
         (creator-balance (default-to { balance: u0 } (map-get? BTCBalances { holder: (get creator option) }))))
        ;; Transfer BTC from holder to creator
        (try! (transfer-btc holder (get creator option) (get btc-amount option)))
        ;; Transfer strike price from creator to holder
        (try! (stx-transfer? strike-amount (get creator option) holder))
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-option (option-id uint))
    (map-get? Options { option-id: option-id })
)

(define-read-only (get-btc-balance (holder principal))
    (default-to { balance: u0 }
        (map-get? BTCBalances { holder: holder }))
)

(define-read-only (get-user-options (user principal))
    (default-to
        { created: (list ), purchased: (list ) }
        (map-get? UserOptions { user: user }))
)

;; Metadata functions using to-ascii? (Clarity 4 feature)

;; ACTUAL to-ascii? USAGE: Convert utf8 string to ascii
(define-read-only (convert-utf8-to-ascii (text (string-utf8 100)))
    (to-ascii? text)
)


;; Example: Get option label with to-ascii? conversion
(define-read-only (get-option-label (option-id uint))
    (match (map-get? Options { option-id: option-id })
        option
            (let ((label-utf8 (if (is-eq (get option-type option) CALL)
                                  u"BTC-CALL-Option"
                                  u"BTC-PUT-Option")))
                (to-ascii? label-utf8))
        (err u999))
)

;; Get human-readable option type name
(define-read-only (get-option-type-name (option-type uint))
    (if (is-eq option-type CALL)
        (some "CALL")
        (if (is-eq option-type PUT)
            (some "PUT")
            none))
)

;; Get option status description
(define-read-only (get-option-status (option-id uint))
    (match (map-get? Options { option-id: option-id })
        option
            (if (get is-executed option)
                (some "EXECUTED")
                (if (>= stacks-block-time (get expiry option))
                    (some "EXPIRED")
                    (if (is-some (get buyer option))
                        (some "ACTIVE-PURCHASED")
                        (some "ACTIVE-AVAILABLE"))))
        none)
)

;; Get full option description with all details
(define-read-only (get-option-details (option-id uint))
    (match (map-get? Options { option-id: option-id })
        option
            (some {
                type: (unwrap-panic (get-option-type-name (get option-type option))),
                status: (unwrap-panic (get-option-status option-id)),
                strike-price: (get strike-price option),
                premium: (get premium option),
                btc-amount: (get btc-amount option),
                expiry: (get expiry option),
                creator: (get creator option),
                buyer: (get buyer option)
            })
        none)
)

;; Oracle functions
(define-public (set-btc-price (price uint))
    (begin
        (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
        (var-set oracle-price price)
        (ok true))
)

;; Set oracle public key (only contract owner)
(define-public (set-oracle-public-key (pubkey (buff 33)))
    (begin
        (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
        (var-set oracle-public-key pubkey)
        (ok true))
)

;; Verified price update using secp256r1-verify (Clarity 4 feature)
;; This ensures the price comes from a trusted oracle with cryptographic proof
(define-public (set-btc-price-verified
    (price uint)
    (timestamp uint)
    (signature (buff 64)))
    (let
        ((message-hash (sha256 (concat (concat (uint-to-buff price) (uint-to-buff timestamp)) 0x42544300))) ;; "BTC" suffix
         (pubkey (var-get oracle-public-key)))

        ;; Verify the signature using secp256r1
        (asserts! (secp256r1-verify message-hash signature pubkey) ERR-INVALID-SIGNATURE)

        ;; Optional: Add timestamp validation to prevent replay attacks
        (asserts! (>= timestamp stacks-block-time) ERR-EXPIRED)

        ;; Update price
        (var-set oracle-price price)
        (ok true))
)

;; Helper to convert uint to buffer for hashing
(define-private (uint-to-buff (value uint))
    (unwrap-panic (to-consensus-buff? value))
)

(define-read-only (get-btc-price)
    (var-get oracle-price)
)

(define-read-only (get-oracle-public-key)
    (var-get oracle-public-key)
)