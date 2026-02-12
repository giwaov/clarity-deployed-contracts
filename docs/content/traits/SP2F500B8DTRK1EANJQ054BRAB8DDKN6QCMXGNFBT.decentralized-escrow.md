---
title: "Trait decentralized-escrow"
draft: true
---
```
;; Decentralized Escrow System
;; Secure P2P transactions with automated release conditions

(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-escrow-not-found (err u101))
(define-constant err-already-released (err u102))
(define-constant err-not-expired (err u103))
(define-constant err-invalid-amount (err u104))

(define-map escrows
    { escrow-id: uint }
    {
        seller: principal,
        buyer: principal,
        amount: uint,
        released: bool,
        created-at: uint,
        expiry: uint
    }
)

(define-data-var escrow-counter uint u0)

;; Create new escrow
(define-public (create-escrow (seller principal) (amount uint) (duration uint))
    (let
        (
            (escrow-id (+ (var-get escrow-counter) u1))
            (current-block stacks-block-height)
        )
        (asserts! (> amount u0) err-invalid-amount)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set escrows
            { escrow-id: escrow-id }
            {
                seller: seller,
                buyer: tx-sender,
                amount: amount,
                released: false,
                created-at: current-block,
                expiry: (+ current-block duration)
            }
        )
        (var-set escrow-counter escrow-id)
        (ok escrow-id)
    )
)

;; Release escrow to seller
(define-public (release-escrow (escrow-id uint))
    (let
        (
            (escrow (unwrap! (map-get? escrows { escrow-id: escrow-id }) err-escrow-not-found))
        )
        (asserts! (is-eq tx-sender (get buyer escrow)) err-not-authorized)
        (asserts! (not (get released escrow)) err-already-released)
        (try! (as-contract (stx-transfer? (get amount escrow) tx-sender (get seller escrow))))
        (map-set escrows
            { escrow-id: escrow-id }
            (merge escrow { released: true })
        )
        (ok true)
    )
)

;; Refund if expired
(define-public (refund-escrow (escrow-id uint))
    (let
        (
            (escrow (unwrap! (map-get? escrows { escrow-id: escrow-id }) err-escrow-not-found))
        )
        (asserts! (>= stacks-block-height (get expiry escrow)) err-not-expired)
        (asserts! (not (get released escrow)) err-already-released)
        (try! (as-contract (stx-transfer? (get amount escrow) tx-sender (get buyer escrow))))
        (map-set escrows
            { escrow-id: escrow-id }
            (merge escrow { released: true })
        )
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-escrow (escrow-id uint))
    (map-get? escrows { escrow-id: escrow-id })
)

```
