---
title: "Trait feedback-loop"
draft: true
---
```
;; feedback-loop.clar
;; Collects user feedback scores

(define-map feedback principal uint)
(define-data-var total-score uint u0)
(define-data-var count uint u0)

(define-public (submit-feedback (score uint))
    (begin
        (asserts! (<= score u5) (err u100)) ;; Max 5 stars
        (map-set feedback tx-sender score)
        (var-set total-score (+ (var-get total-score) score))
        (var-set count (+ (var-get count) u1))
        (ok true)
    )
)

(define-read-only (get-average)
    (if (is-eq (var-get count) u0)
        (ok u0)
        (ok (/ (var-get total-score) (var-get count)))
    )
)

```
