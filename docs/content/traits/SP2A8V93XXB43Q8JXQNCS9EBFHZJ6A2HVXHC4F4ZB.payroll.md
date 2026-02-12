---
title: "Trait payroll"
draft: true
---
```
;; Counter contract - Clarity v3

(define-data-var counter int 0)

;; Increments the counter by 1 and returns the new value
(define-public (increment)
  (let ((current (var-get counter)))
    (begin
      (var-set counter (+ current 1))
      (ok (+ current 1)))))

;; Decrements the counter by 1 and returns the new value
(define-public (decrement)
  (let ((current (var-get counter)))
    (begin
      (var-set counter (- current 1))
      (ok (- current 1)))))

;; Sets the counter to a specific value and returns it
(define-public (set (value int))
  (begin
    (var-set counter value)
    (ok value)))

;; Returns the current counter value
(define-read-only (get-counter)
  (var-get counter))

```
