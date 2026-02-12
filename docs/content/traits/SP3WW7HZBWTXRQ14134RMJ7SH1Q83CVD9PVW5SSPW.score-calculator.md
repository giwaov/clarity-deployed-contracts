---
title: "Trait score-calculator"
draft: true
---
```
;; Score Calculator

(define-map reputation-scores principal uint)

(define-public (update-score (user principal) (score uint))
  (begin
    (map-set reputation-scores user score)
    (ok score)
  )
)

(define-read-only (get-score (user principal))
  (default-to u0 (map-get? reputation-scores user))
)

```
