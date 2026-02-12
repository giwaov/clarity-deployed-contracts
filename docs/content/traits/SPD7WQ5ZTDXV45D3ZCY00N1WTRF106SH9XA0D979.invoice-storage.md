---
title: "Trait invoice-storage"
draft: true
---
```
;; invoice-storage.clar
;; Stores invoice records on-chain

(define-constant err-unauthorized (err u400))
(define-constant err-invalid-params (err u401))

(define-map invoices
    uint  ;; invoice-id
    {
        subscriber: principal,
        plan-id: uint,
        amount: uint,
        created-at: uint,
        period-start: uint,
        period-end: uint,
        status: (string-ascii 20)
    }
)

(define-data-var next-invoice-id uint u1)

(define-public (create-invoice
    (subscriber principal)
    (plan-id uint)
    (amount uint)
    (period-start uint)
    (period-end uint)
)
    (let (
        (invoice-id (var-get next-invoice-id))
    )
        (asserts! (> amount u0) err-invalid-params)
        
        (map-set invoices
            invoice-id
            {
                subscriber: subscriber,
                plan-id: plan-id,
                amount: amount,
                created-at: stacks-block-height,
                period-start: period-start,
                period-end: period-end,
                status: "paid"
            }
        )
        
        (var-set next-invoice-id (+ invoice-id u1))
        (ok invoice-id)
    )
)

(define-read-only (get-invoice (invoice-id uint))
    (ok (map-get? invoices invoice-id))
)


```
