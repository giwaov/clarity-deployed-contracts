---
title: "Trait Operation-Control"
draft: true
---
```

;; Operation Control
;; Manages operational flags for the decentralized system

(define-data-var system-active bool true)

(define-read-only (is-system-active)
    (ok (var-get system-active))
)

(define-public (toggle-system-state)
    (begin
        (var-set system-active (not (var-get system-active)))
        (ok (var-get system-active))
    )
)

```
