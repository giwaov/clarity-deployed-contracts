;; Recurring Payment Smart Contract
;; Enables subscription-based and recurring payments (rent, retainers, SaaS)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u500))
(define-constant err-invalid-subscription (err u501))
(define-constant err-unauthorized (err u502))
(define-constant err-insufficient-balance (err u503))
(define-constant err-subscription-not-found (err u504))
(define-constant err-already-cancelled (err u505))
(define-constant err-not-due (err u506))
(define-constant err-invalid-interval (err u507))

;; Platform fee: 1% for recurring payments
(define-constant platform-fee-percentage u1)
(define-constant blocks-per-day u144) ;; ~10 min blocks
(define-constant blocks-per-week u1008)
(define-constant blocks-per-month u4320)
(define-constant blocks-per-year u52560)

;; Data Variables
(define-data-var total-subscriptions uint u0)
(define-data-var total-fees-collected uint u0)
(define-data-var total-payments-processed uint u0)

;; Data Maps
(define-map subscriptions
    uint
    {
        payer: principal,
        payee: principal,
        amount: uint,
        interval-blocks: uint, ;; Number of blocks between payments
        start-block: uint,
        next-payment-block: uint,
        total-payments-made: uint,
        is-active: bool,
        description: (string-ascii 100),
        created-at: uint
    }
)

(define-map payment-history
    { subscription-id: uint, payment-number: uint }
    {
        amount: uint,
        fee: uint,
        block-height: uint,
        status: (string-ascii 20)
    }
)

;; Read-only functions
(define-read-only (get-subscription (subscription-id uint))
    (map-get? subscriptions subscription-id)
)

(define-read-only (get-payment-record (subscription-id uint) (payment-number uint))
    (map-get? payment-history { subscription-id: subscription-id, payment-number: payment-number })
)

(define-read-only (get-total-subscriptions)
    (ok (var-get total-subscriptions))
)

(define-read-only (get-total-fees)
    (ok (var-get total-fees-collected))
)

(define-read-only (is-payment-due (subscription-id uint))
    (match (map-get? subscriptions subscription-id)
        subscription
            (ok (and 
                (get is-active subscription)
                (>= stacks-block-height (get next-payment-block subscription))
            ))
        (ok false)
    )
)

;; Public functions

;; Create a new subscription
(define-public (create-subscription
    (payee principal)
    (amount uint)
    (interval-type (string-ascii 10)) ;; "daily", "weekly", "monthly", "yearly"
    (description (string-ascii 100))
)
    (let
        (
            (subscription-id (+ (var-get total-subscriptions) u1))
            (interval-blocks (if (is-eq interval-type "daily")
                blocks-per-day
                (if (is-eq interval-type "weekly")
                    blocks-per-week
                    (if (is-eq interval-type "monthly")
                        blocks-per-month
                        (if (is-eq interval-type "yearly")
                            blocks-per-year
                            u0
                        )
                    )
                )
            ))
        )
        ;; Validations
        (asserts! (> interval-blocks u0) err-invalid-interval)
        (asserts! (> amount u0) err-invalid-subscription)
        (asserts! (not (is-eq payee tx-sender)) err-invalid-subscription)
        
        ;; Store subscription
        (map-set subscriptions subscription-id
            {
                payer: tx-sender,
                payee: payee,
                amount: amount,
                interval-blocks: interval-blocks,
                start-block: stacks-block-height,
                next-payment-block: stacks-block-height, ;; First payment due immediately
                total-payments-made: u0,
                is-active: true,
                description: description,
                created-at: stacks-block-height
            }
        )
        
        (var-set total-subscriptions subscription-id)
        
        (ok subscription-id)
    )
)

;; Execute a subscription payment
(define-public (execute-payment (subscription-id uint))
    (let
        (
            (subscription (unwrap! (map-get? subscriptions subscription-id) err-subscription-not-found))
            (fee-amount (/ (* (get amount subscription) platform-fee-percentage) u100))
            (net-amount (- (get amount subscription) fee-amount))
            (next-payment-number (+ (get total-payments-made subscription) u1))
        )
        ;; Validations
        (asserts! (get is-active subscription) err-already-cancelled)
        (asserts! (>= stacks-block-height (get next-payment-block subscription)) err-not-due)
        
        ;; Transfer payment
        (try! (stx-transfer? net-amount tx-sender (get payee subscription)))
        
        ;; Collect platform fee
        (try! (stx-transfer? fee-amount tx-sender contract-owner))
        
        ;; Update statistics
        (var-set total-fees-collected (+ (var-get total-fees-collected) fee-amount))
        (var-set total-payments-processed (+ (var-get total-payments-processed) u1))
        
        ;; Record payment
        (map-set payment-history 
            { subscription-id: subscription-id, payment-number: next-payment-number }
            {
                amount: (get amount subscription),
                fee: fee-amount,
                block-height: stacks-block-height,
                status: "completed"
            }
        )
        
        ;; Update subscription
        (map-set subscriptions subscription-id
            (merge subscription {
                next-payment-block: (+ stacks-block-height (get interval-blocks subscription)),
                total-payments-made: next-payment-number
            })
        )
        
        (ok next-payment-number)
    )
)

;; Cancel a subscription (payer only)
(define-public (cancel-subscription (subscription-id uint))
    (let
        (
            (subscription (unwrap! (map-get? subscriptions subscription-id) err-subscription-not-found))
        )
        (asserts! (is-eq tx-sender (get payer subscription)) err-unauthorized)
        (asserts! (get is-active subscription) err-already-cancelled)
        
        (map-set subscriptions subscription-id
            (merge subscription { is-active: false })
        )
        
        (ok true)
    )
)

;; Reactivate a subscription (payer only)
(define-public (reactivate-subscription (subscription-id uint))
    (let
        (
            (subscription (unwrap! (map-get? subscriptions subscription-id) err-subscription-not-found))
        )
        (asserts! (is-eq tx-sender (get payer subscription)) err-unauthorized)
        (asserts! (not (get is-active subscription)) err-invalid-subscription)
        
        (map-set subscriptions subscription-id
            (merge subscription { 
                is-active: true,
                next-payment-block: stacks-block-height ;; Reset to immediate payment
            })
        )
        
        (ok true)
    )
)

;; Update subscription amount (requires both parties' approval via separate calls)
(define-public (update-amount (subscription-id uint) (new-amount uint))
    (let
        (
            (subscription (unwrap! (map-get? subscriptions subscription-id) err-subscription-not-found))
        )
        (asserts! (or 
            (is-eq tx-sender (get payer subscription))
            (is-eq tx-sender (get payee subscription))
        ) err-unauthorized)
        (asserts! (> new-amount u0) err-invalid-subscription)
        
        (map-set subscriptions subscription-id
            (merge subscription { amount: new-amount })
        )
        
        (ok true)
    )
)
