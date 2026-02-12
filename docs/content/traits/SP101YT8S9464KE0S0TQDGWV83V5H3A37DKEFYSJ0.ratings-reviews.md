---
title: "Trait ratings-reviews"
draft: true
---
```
;; Ratings & Reviews - Rate and review

(define-map reviews
  uint
  {
    reviewer: principal,
    target: principal,
    rating: uint,
    comment: (string-utf8 300),
    created-at: uint
  }
)

(define-data-var review-counter uint u0)

(define-public (submit-review (target principal) (rating uint) (comment (string-utf8 300)))
  (let ((id (var-get review-counter)))
    (asserts! (and (>= rating u1) (<= rating u5)) (err u400))
    (map-set reviews id {
      reviewer: tx-sender,
      target: target,
      rating: rating,
      comment: comment,
      created-at: stacks-block-height
    })
    (var-set review-counter (+ id u1))
    (ok id)
  )
)

(define-read-only (get-review (id uint))
  (map-get? reviews id)
)

```
