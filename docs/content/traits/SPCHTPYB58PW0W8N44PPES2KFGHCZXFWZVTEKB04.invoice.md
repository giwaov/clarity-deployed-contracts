---
title: "Trait invoice"
draft: true
---
```
;; Invoice Contract
;; Create and pay invoices on-chain

(define-constant err-not-found (err u100))
(define-constant err-already-paid (err u101))
(define-constant err-insufficient-payment (err u102))
(define-constant err-not-authorized (err u103))

(define-data-var invoice-nonce uint u0)

(define-map invoices
    uint
    {
        issuer: principal,
        payer: principal,
        amount: uint,
        description: (string-utf8 500),
        due-block: uint,
        paid: bool,
        paid-block: (optional uint)
    }
)

(define-public (create-invoice
    (payer principal)
    (amount uint)
    (description (string-utf8 500))
    (due-block uint))
    (let ((invoice-id (var-get invoice-nonce)))
        (map-set invoices invoice-id {
            issuer: tx-sender,
            payer: payer,
            amount: amount,
            description: description,
            due-block: due-block,
            paid: false,
            paid-block: none
        })
        (var-set invoice-nonce (+ invoice-id u1))
        (ok invoice-id)
    )
)

(define-public (pay-invoice (invoice-id uint))
    (let ((invoice (unwrap! (map-get? invoices invoice-id) err-not-found)))
        (asserts! (is-eq tx-sender (get payer invoice)) err-not-authorized)
        (asserts! (not (get paid invoice)) err-already-paid)
        
        (try! (stx-transfer? (get amount invoice) tx-sender (get issuer invoice)))
        
        (map-set invoices invoice-id (merge invoice {
            paid: true,
            paid-block: (some block-height)
        }))
        (ok true)
    )
)

(define-public (cancel-invoice (invoice-id uint))
    (let ((invoice (unwrap! (map-get? invoices invoice-id) err-not-found)))
        (asserts! (is-eq tx-sender (get issuer invoice)) err-not-authorized)
        (asserts! (not (get paid invoice)) err-already-paid)
        (map-delete invoices invoice-id)
        (ok true)
    )
)

(define-read-only (get-invoice (invoice-id uint))
    (map-get? invoices invoice-id)
)

(define-read-only (is-overdue (invoice-id uint))
    (match (map-get? invoices invoice-id)
        invoice (and (not (get paid invoice)) (> block-height (get due-block invoice)))
        false)
)

```
