---
title: "Trait fundme"
draft: true
---
```
;; Simple FundMe Contract

;; Owner who receives funds
(define-constant owner tx-sender)

;; Track total funds received
(define-data-var total uint u0)

;; Anyone can send STX
(define-public (fund (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set total (+ (var-get total) amount))
    (ok true)
  )
)

;; Owner withdraws all funds
(define-public (withdraw)
  (begin
    (asserts! (is-eq tx-sender owner) (err u1))
    (try! (as-contract (stx-transfer? (var-get total) tx-sender owner)))
    (var-set total u0)
    (ok true)
  )
)

;; Check total funds
(define-read-only (get-total)
  (var-get total)
)
```
