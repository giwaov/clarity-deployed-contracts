
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_TIME (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_INVALID_RECIPIENT (err u103))
(define-constant ERR_INVALID_AMOUNT (err u104))
(define-constant ERR_EMERGENCY_NOT_ACTIVE (err u105))
(define-constant ERR_ALLOWANCE_EXCEEDED (err u106))
(define-constant ERR_INSUFFICIENT_SIGNATURES (err u107))
(define-constant ERR_ALREADY_EXECUTED (err u108))
(define-constant ERR_PAYMENT_INACTIVE (err u109))
(define-constant ERR_INVALID_FREQUENCY (err u110))

;; Data variables
(define-data-var minimum-lock-period uint u1440) ;; minimum lock period in blocks (approximately 10 days)
(define-data-var emergency-withdrawal-fee uint u5) ;; 5% fee for emergency withdrawals
(define-data-var current-block-height uint u0)
(define-data-var transaction-counter uint u0)

(define-map time-locked-savings 
    principal 
    {
        amount: uint,
        unlock-height: uint,
        is-active: bool,
        emergency-contact: (optional principal)
    }
)

(define-map split-payment-settings
    principal
    {
        recipients: (list 10 principal),
        percentages: (list 10 uint),
        is-active: bool
    }
)

;; NEW: Recurring payment map
(define-map recurring-payments
    { owner: principal, payment-id: uint }
    {
        recipient: principal,
        amount: uint,
        frequency: uint, ;; in blocks
        last-payment-height: uint,
        end-height: (optional uint),
        is-active: bool
    }
)

;; NEW: Allowance system map
(define-map allowances
    { owner: principal, spender: principal }
    {
        amount: uint,
        expiry-height: (optional uint)
    }
)

;; NEW: Multi-signature transaction map
(define-map multi-sig-transactions
    { tx-id: uint }
    {
        owner: principal,
        required-signatures: uint,
        signers: (list 10 principal),
        signatures: (list 10 principal),
        recipient: principal,
        amount: uint,
        memo: (optional (buff 34)),
        expiry-height: uint,
        executed: bool
    }
)

;; NEW: Multi-signature settings map
(define-map multi-sig-settings
    principal
    {
        signers: (list 10 principal),
        required-signatures: uint,
        is-active: bool
    }
)

;; Read-only functions
(define-read-only (get-balance (user principal))
    (default-to u0 
        (get amount (map-get? time-locked-savings user))))

(define-read-only (get-unlock-height (user principal))
    (default-to u0 
        (get unlock-height (map-get? time-locked-savings user))))

(define-read-only (get-split-payment-info (user principal))
    (map-get? split-payment-settings user))

(define-read-only (get-emergency-contact (user principal))
    (get emergency-contact (default-to 
        { amount: u0, unlock-height: u0, is-active: false, emergency-contact: none }
        (map-get? time-locked-savings user))))

(define-read-only (get-current-block-height)
    (var-get current-block-height))

;; NEW: Recurring payment read-only functions
(define-read-only (get-recurring-payment (owner principal) (payment-id uint))
    (map-get? recurring-payments { owner: owner, payment-id: payment-id }))

(define-read-only (get-allowance (owner principal) (spender principal))
    (default-to u0 
        (get amount (map-get? allowances { owner: owner, spender: spender }))))

(define-read-only (get-multi-sig-transaction (tx-id uint))
    (map-get? multi-sig-transactions { tx-id: tx-id }))

(define-read-only (get-multi-sig-settings (owner principal))
    (map-get? multi-sig-settings owner))

;; Time-locked savings functions
(define-public (create-time-lock (amount uint) (lock-blocks uint) (emergency-contact (optional principal)))
    (let
        (
            (unlock-at (+ (var-get current-block-height) lock-blocks))
        )
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (>= lock-blocks (var-get minimum-lock-period)) ERR_INVALID_TIME)
        (asserts! (>= (stx-get-balance tx-sender) amount) ERR_INSUFFICIENT_BALANCE)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (ok (map-set time-locked-savings tx-sender
            {
                amount: amount,
                unlock-height: unlock-at,
                is-active: true,
                emergency-contact: emergency-contact
            }))))

(define-public (withdraw)
    (let
        (
            (savings-data (unwrap! (map-get? time-locked-savings tx-sender) ERR_NOT_AUTHORIZED))
            (amount (get amount savings-data))
            (unlock-height (get unlock-height savings-data))
        )
        (asserts! (get is-active savings-data) ERR_NOT_AUTHORIZED)
        (asserts! (>= (var-get current-block-height) unlock-height) ERR_INVALID_TIME)
        (map-delete time-locked-savings tx-sender)
        (as-contract (stx-transfer? amount tx-sender tx-sender))))

(define-public (emergency-withdraw)
    (let
        (
            (savings-data (unwrap! (map-get? time-locked-savings tx-sender) ERR_NOT_AUTHORIZED))
            (amount (get amount savings-data))
            (fee-amount (/ (* amount (var-get emergency-withdrawal-fee)) u100))
            (withdrawal-amount (- amount fee-amount))
        )
        (asserts! (get is-active savings-data) ERR_NOT_AUTHORIZED)
        (asserts! (< (var-get current-block-height) (get unlock-height savings-data)) ERR_EMERGENCY_NOT_ACTIVE)
        (map-delete time-locked-savings tx-sender)
        (as-contract (begin
            (try! (stx-transfer? withdrawal-amount tx-sender tx-sender))
            (stx-transfer? fee-amount tx-sender CONTRACT_OWNER)))))
