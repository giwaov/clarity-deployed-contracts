---
title: "Trait basic-escrow"
draft: true
---
```
;; basic-escrow.clar
;; Simple Buyer-Seller-Arbiter escrow

(define-data-var buyer principal tx-sender)
(define-data-var seller principal tx-sender)
(define-data-var arbiter principal tx-sender)
(define-data-var price uint u1000)
(define-data-var balance uint u0)

(define-public (initialize (new-buyer principal) (new-seller principal) (new-arbiter principal) (new-price uint))
    (begin
        ;; Only allow initialization if balance is 0
        (asserts! (is-eq (var-get balance) u0) (err u100))
        (var-set buyer new-buyer)
        (var-set seller new-seller)
        (var-set arbiter new-arbiter)
        (var-set price new-price)
        (ok true)
    )
)

(define-public (detect-deposit)
    (begin
        (asserts! (is-eq tx-sender (var-get buyer)) (err u101))
        (try! (stx-transfer? (var-get price) tx-sender (as-contract tx-sender)))
        (var-set balance (var-get price))
        (ok true)
    )
)

(define-public (release-to-seller)
    (begin
        (asserts! (is-eq tx-sender (var-get arbiter)) (err u102))
        (asserts! (> (var-get balance) u0) (err u103))
        (try! (as-contract (stx-transfer? (var-get balance) tx-sender (var-get seller))))
        (var-set balance u0)
        (ok true)
    )
)

(define-public (refund-buyer)
    (begin
        (asserts! (is-eq tx-sender (var-get arbiter)) (err u102))
        (asserts! (> (var-get balance) u0) (err u103))
        (try! (as-contract (stx-transfer? (var-get balance) tx-sender (var-get buyer))))
        (var-set balance u0)
        (ok true)
    )
)

```
