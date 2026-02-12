---
title: "Trait counter-alpha"
draft: true
---
```
;; Simple counter contract - increment/decrement operations
(define-data-var counter uint u0)
(define-data-var owner principal tx-sender)

(define-read-only (get-counter)
  (var-get counter)
)

(define-public (increment)
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err u1))
    (ok (var-set counter (+ (var-get counter) u1)))
  )
)

(define-public (decrement)
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err u1))
    (asserts! (> (var-get counter) u0) (err u2))
    (ok (var-set counter (- (var-get counter) u1)))
  )
)

(define-public (reset)
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err u1))
    (ok (var-set counter u0))
  )
)

```
