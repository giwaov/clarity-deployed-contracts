---
title: "Trait counter"
draft: true
---
```
;; Simple Counter Contract
;; A basic counter that can be incremented by anyone

;; Data Variables
(define-data-var counter uint u0)

;; Read-only function to get the current counter value
(define-read-only (get-counter)
  (var-get counter)
)

;; Public function to increment the counter by 1
(define-public (increment)
  (begin
    (var-set counter (+ (var-get counter) u1))
    (ok (var-get counter))
  )
)

;; Public function to increment the counter by a specific amount
(define-public (increment-by (amount uint))
  (begin
    (var-set counter (+ (var-get counter) amount))
    (ok (var-get counter))
  )
)

```
