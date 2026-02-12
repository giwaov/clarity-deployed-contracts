---
title: "Trait pause-guardian"
draft: true
---
```
;; ---------------------------------------------------------
;; Pause Guardian
;; Emergency pause toggle
;; ---------------------------------------------------------

(define-data-var paused bool false)


(define-public (toggle)
    (begin
        (var-set paused (not (var-get paused)))
        (ok (var-get paused))
    )
)

```
