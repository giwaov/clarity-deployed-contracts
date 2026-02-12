
;; Nova Subscription Flow
;; Manages recurring payments and subscriptions

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-SUBSCRIPTION-EXPIRED (err u101))

(define-map subscriptions
    { subscriber: principal, service: principal }
    {
        amount: uint,
        interval: uint,
        next-payment: uint,
        active: bool
    }
)

(define-public (subscribe (service principal) (amount uint) (interval uint))
    (begin
        ;; Initial payment
        (try! (stx-transfer? amount tx-sender service))
        (ok (map-set subscriptions
            { subscriber: tx-sender, service: service }
            {
                amount: amount,
                interval: interval,
                next-payment: (+ block-height interval),
                active: true
            }
        ))
    )
)

(define-public (process-renewal (subscriber principal))
    (let
        (
            (sub (unwrap! (map-get? subscriptions { subscriber: subscriber, service: tx-sender }) (err u404)))
        )
        (asserts! (get active sub) ERR-SUBSCRIPTION-EXPIRED)
        (asserts! (>= block-height (get next-payment sub)) ERR-SUBSCRIPTION-EXPIRED)
        
        ;; In a real implementation we would need pre-approved allowance or authorized operator
        ;; For now we simulate the check
        (ok (map-set subscriptions
            { subscriber: subscriber, service: tx-sender }
            (merge sub { next-payment: (+ block-height (get interval sub)) })
        ))
    )
)
