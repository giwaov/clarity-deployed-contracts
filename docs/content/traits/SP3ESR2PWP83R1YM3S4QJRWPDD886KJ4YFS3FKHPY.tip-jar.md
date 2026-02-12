---
title: "Trait tip-jar"
draft: true
---
```
;; Tip Jar

(define-map tips
  principal
  { total: uint, count: uint }
)

(define-public (send-tip (creator principal) (amount uint))
  (let ((current (default-to { total: u0, count: u0 } (map-get? tips creator))))
    (map-set tips creator { total: (+ (get total current) amount), count: (+ (get count current) u1) })
    (ok true)
  )
)

(define-read-only (get-tips (creator principal))
  (default-to { total: u0, count: u0 } (map-get? tips creator))
)

```
