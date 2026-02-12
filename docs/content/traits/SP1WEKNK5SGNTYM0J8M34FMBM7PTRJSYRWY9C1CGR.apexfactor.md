---
title: "Trait apexfactor"
draft: true
---
```
;; title: apexfactor
;; version: 1.0.0
;; summary: A decentralized invoice factoring platform
;; description: Allows businesses to sell invoices to investors for immediate cash flow.

;; traits
;;

;; token definitions
;;

;; constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVOICE-NOT-FOUND (err u101))
(define-constant ERR-INSUFFICIENT-FUNDS (err u102))
(define-constant ERR-INVOICE-ALREADY-PAID (err u103))
(define-constant ERR-INVALID-STATE (err u104))
(define-constant ERR-INVOICE-EXPIRED (err u105))

(define-constant STATUS-OPEN "OPEN")
(define-constant STATUS-FUNDED "FUNDED")
(define-constant STATUS-PAID "PAID")
(define-constant STATUS-DISPUTED "DISPUTED")

;; data vars
(define-data-var next-invoice-id uint u1)
(define-data-var utility-counter uint u0)

;; data maps
(define-map invoices
    uint
    {
        seller: principal,
        amount: uint,
        due-date: uint,
        status: (string-ascii 10),
        buyer: (optional principal),
        customer: (string-ascii 50)
    }
)

;; public functions

;; Invoice Management

(define-public (create-invoice (amount uint) (due-date uint) (customer (string-ascii 50)))
    (let
        (
            (invoice-id (var-get next-invoice-id))
        )
        (map-set invoices invoice-id {
            seller: tx-sender,
            amount: amount,
            due-date: due-date,
            status: STATUS-OPEN,
            buyer: none,
            customer: customer
        })
        (var-set next-invoice-id (+ invoice-id u1))
        (ok invoice-id)
    )
)

(define-public (purchase-invoice (invoice-id uint))
    (let
        (
            (invoice (unwrap! (map-get? invoices invoice-id) ERR-INVOICE-NOT-FOUND))
            (price (get amount invoice))
            (seller (get seller invoice))
        )
        (asserts! (is-eq (get status invoice) STATUS-OPEN) ERR-INVALID-STATE)
        
        ;; In a real scenario, we would transfer STX here using stx-transfer?
        (try! (stx-transfer? price tx-sender seller))

        (map-set invoices invoice-id (merge invoice {
            status: STATUS-FUNDED,
            buyer: (some tx-sender)
        }))
        (ok true)
    )
)

(define-public (pay-invoice (invoice-id uint))
    (let
        (
            (invoice (unwrap! (map-get? invoices invoice-id) ERR-INVOICE-NOT-FOUND))
            (amount (get amount invoice))
            (buyer (unwrap! (get buyer invoice) ERR-INVALID-STATE)) ;; Must look for buyer to pay back
        )
        (asserts! (is-eq (get status invoice) STATUS-FUNDED) ERR-INVALID-STATE)

        ;; Payer (customer) pays back the investor (buyer)
        (try! (stx-transfer? amount tx-sender buyer))

        (map-set invoices invoice-id (merge invoice {
            status: STATUS-PAID
        }))
        (ok true)
    )
)

(define-public (dispute-invoice (invoice-id uint))
    (let
        (
            (invoice (unwrap! (map-get? invoices invoice-id) ERR-INVOICE-NOT-FOUND))
        )
        ;; Only seller or buyer can likely dispute, simplifed here
        (asserts! (or (is-eq tx-sender (get seller invoice)) 
                      (is-eq (some tx-sender) (get buyer invoice)))
                  ERR-NOT-AUTHORIZED)
        
        (map-set invoices invoice-id (merge invoice {
            status: STATUS-DISPUTED
        }))
        (ok true)
    )
)

;; Utility Counter Functions

(define-public (count-up)
    (begin
        (var-set utility-counter (+ (var-get utility-counter) u1))
        (ok (var-get utility-counter))
    )
)

(define-public (count-down)
    (begin
        (var-set utility-counter (- (var-get utility-counter) u1))
        (ok (var-get utility-counter))
    )
)

;; read only functions

(define-read-only (get-invoice (invoice-id uint))
    (map-get? invoices invoice-id)
)

(define-read-only (get-counter-value)
    (var-get utility-counter)
)

```
