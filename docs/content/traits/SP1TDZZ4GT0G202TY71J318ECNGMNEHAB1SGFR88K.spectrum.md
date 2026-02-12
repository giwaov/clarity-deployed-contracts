---
title: "Trait spectrum"
draft: true
---
```
;; title: stxpcounter
;; version:
;; summary:
;; description:

;; data vars
(define-data-var counter uint u0)

;; public functions

;; Increment the counter by 1
(define-public (increment)
  (let ((current-count (var-get counter)))
    (var-set counter (+ current-count u1))
    (ok (var-get counter))
  )
)

;; Decrement the counter by 1 (only if counter > 0)
(define-public (decrement)
  (let ((current-count (var-get counter)))
    (asserts! (> current-count u0) (err u1)) ;; Error if counter is 0
    (var-set counter (- current-count u1))
    (ok (var-get counter))
  )
)

;; Reset the counter to 0
(define-public (reset)
  (begin
    (var-set counter u0)
    (ok u0)
  )
)

;; read only functions

;; Get the current counter value
(define-read-only (get-counter)
  (ok (var-get counter))
)

```
