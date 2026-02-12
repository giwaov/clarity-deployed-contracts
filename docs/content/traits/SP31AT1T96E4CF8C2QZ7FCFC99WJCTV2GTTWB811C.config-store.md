---
title: "Trait config-store"
draft: true
---
```
(define-map config (string-ascii 20) uint)

(define-public (set-config (key (string-ascii 20)) (val uint))
    (begin
        (map-set config key val)
        (ok true)
    )
)

```
