---
title: "Trait leaderboard"
draft: true
---
```
;; Leaderboard contract for tracking scores
(define-map scores principal uint)
(define-data-var top-score uint u0)
(define-data-var top-scorer principal tx-sender)
(define-data-var total-players uint u0)

(define-read-only (get-score (player principal))
  (default-to u0 (map-get? scores player))
)

(define-read-only (get-top-score)
  (var-get top-score)
)

(define-read-only (get-top-scorer)
  (var-get top-scorer)
)

(define-public (submit-score (score uint))
  (let ((current (get-score tx-sender)))
    (begin
      (asserts! (> score current) (err u1))
      (map-set scores tx-sender score)
      (if (> score (var-get top-score))
        (begin
          (var-set top-score score)
          (var-set top-scorer tx-sender)
        )
        false
      )
      (ok true)
    )
  )
)

```
