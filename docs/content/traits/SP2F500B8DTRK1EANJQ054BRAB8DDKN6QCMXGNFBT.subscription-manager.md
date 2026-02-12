---
title: "Trait subscription-manager"
draft: true
---
```
;; Subscription Manager - Clarity 4
;; Recurring subscription payments

(define-constant contract-owner tx-sender)
(define-constant err-not-active (err u7000))
(define-constant err-payment-failed (err u7001))

(define-data-var subscription-nonce uint u0)

(define-map subscriptions
    uint
    {
        subscriber: principal,
        provider: principal,
        amount-per-period: uint,
        period-length: uint,
        start-height: uint,
        last-payment: uint,
        active: bool,
        total-paid: uint
    }
)

(define-map subscriber-subs principal (list 20 uint))

(define-read-only (get-subscription (sub-id uint))
    (map-get? subscriptions sub-id)
)

(define-read-only (is-payment-due (sub-id uint))
    (match (get-subscription sub-id)
        sub
        (let (
            (next-payment (+ (get last-payment sub) (get period-length sub)))
        )
            (and (get active sub) (>= stacks-block-height next-payment))
        )
        false
    )
)

(define-public (create-subscription
    (provider principal)
    (amount uint)
    (period-blocks uint)
)
    (let (
        (sub-id (var-get subscription-nonce))
        (user-subs (default-to (list) (map-get? subscriber-subs tx-sender)))
    )
        (map-set subscriptions sub-id {
            subscriber: tx-sender,
            provider: provider,
            amount-per-period: amount,
            period-length: period-blocks,
            start-height: stacks-block-height,
            last-payment: stacks-block-height,
            active: true,
            total-paid: u0
        })
        
        (map-set subscriber-subs tx-sender
            (unwrap-panic (as-max-len? (append user-subs sub-id) u20))
        )
        (var-set subscription-nonce (+ sub-id u1))
        (ok sub-id)
    )
)

(define-public (process-payment (sub-id uint))
    (let (
        (sub (unwrap! (get-subscription sub-id) err-not-active))
    )
        (asserts! (is-payment-due sub-id) err-not-active)
        
        (try! (stx-transfer? (get amount-per-period sub) 
            (get subscriber sub) (get provider sub)))
        
        (ok (map-set subscriptions sub-id 
            (merge sub {
                last-payment: stacks-block-height,
                total-paid: (+ (get total-paid sub) (get amount-per-period sub))
            })
        ))
    )
)

(define-public (cancel-subscription (sub-id uint))
    (let (
        (sub (unwrap! (get-subscription sub-id) err-not-active))
    )
        (asserts! (is-eq tx-sender (get subscriber sub)) err-not-active)
        (ok (map-set subscriptions sub-id (merge sub {active: false})))
    )
)

```
