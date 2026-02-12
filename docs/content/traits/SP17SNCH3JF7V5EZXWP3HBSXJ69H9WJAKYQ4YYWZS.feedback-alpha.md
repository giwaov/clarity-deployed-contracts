---
title: "Trait feedback-alpha"
draft: true
---
```
;; Feedback collection contract
(define-map feedback {id: uint} {author: principal, rating: uint, comment: (string-utf8 512), timestamp: uint})
(define-data-var feedback-counter uint u0)
(define-data-var total-rating uint u0)
(define-data-var feedback-count uint u0)

(define-read-only (get-feedback (id uint))
  (map-get? feedback {id: id})
)

(define-read-only (get-average-rating)
  (if (> (var-get feedback-count) u0)
    (/ (var-get total-rating) (var-get feedback-count))
    u0
  )
)

(define-public (submit-feedback (rating uint) (comment (string-utf8 512)))
  (let ((id (var-get feedback-counter)))
    (begin
      (asserts! (<= rating u5) (err u1))
      (map-set feedback {id: id} {
        author: tx-sender,
        rating: rating,
        comment: comment,
        timestamp: burn-block-height
      })
      (var-set total-rating (+ (var-get total-rating) rating))
      (var-set feedback-count (+ (var-get feedback-count) u1))
      (ok (var-set feedback-counter (+ id u1)))
    )
  )
)

```
