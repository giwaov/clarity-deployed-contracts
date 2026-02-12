---
title: "Trait rating-system"
draft: true
---
```
;; Rating System

(define-map ratings
  { target: principal, rater: principal }
  { score: uint }
)

(define-map rating-totals
  principal
  { sum: uint, count: uint }
)

(define-public (rate (target principal) (score uint))
  (begin
    (asserts! (and (>= score u1) (<= score u5)) (err u400))
    (asserts! (is-none (map-get? ratings { target: target, rater: tx-sender })) (err u409))
    (map-set ratings { target: target, rater: tx-sender } { score: score })
    (let ((current (default-to { sum: u0, count: u0 } (map-get? rating-totals target))))
      (map-set rating-totals target { sum: (+ (get sum current) score), count: (+ (get count current) u1) })
    )
    (ok true)
  )
)

(define-read-only (get-rating (target principal) (rater principal))
  (map-get? ratings { target: target, rater: rater })
)

(define-read-only (get-average (target principal))
  (let ((totals (default-to { sum: u0, count: u0 } (map-get? rating-totals target))))
    (if (is-eq (get count totals) u0)
      u0
      (/ (get sum totals) (get count totals))
    )
  )
)

```
