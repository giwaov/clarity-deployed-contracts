---
title: "Trait counter"
draft: true
---
```
;; Counter Contract
;; A simple counter that can be incremented, decremented, and reset

(define-data-var counter int 0)
(define-data-var owner principal tx-sender)

;; Read-only functions
(define-read-only (get-counter)
  (ok (var-get counter))
)

(define-read-only (get-owner)
  (ok (var-get owner))
)

;; Public functions
(define-public (increment)
  (begin
    (var-set counter (+ (var-get counter) 1))
    (ok (var-get counter))
  )
)

(define-public (decrement)
  (begin
    (var-set counter (- (var-get counter) 1))
    (ok (var-get counter))
  )
)

(define-public (add (value int))
  (begin
    (var-set counter (+ (var-get counter) value))
    (ok (var-get counter))
  )
)

(define-public (subtract (value int))
  (begin
    (var-set counter (- (var-get counter) value))
    (ok (var-get counter))
  )
)

(define-public (reset)
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err u100))
    (var-set counter 0)
    (ok 0)
  )
)

(define-public (set-value (value int))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err u100))
    (var-set counter value)
    (ok value)
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err u100))
    (var-set owner new-owner)
    (ok new-owner)
  )
)

```
