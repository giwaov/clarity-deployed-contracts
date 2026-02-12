---
title: "Trait reputation"
draft: true
---
```
;; reputation.clar
;; Score tracking system

(define-map scores principal int)

(define-public (add-reputation (user principal) (points int))
    (let
        (
            (current (default-to 0 (map-get? scores user)))
        )
        ;; Restricted to admin in reality
        (ok (map-set scores user (+ current points)))
    )
)

(define-read-only (get-reputation (user principal))
    (default-to 0 (map-get? scores user))
)

```
