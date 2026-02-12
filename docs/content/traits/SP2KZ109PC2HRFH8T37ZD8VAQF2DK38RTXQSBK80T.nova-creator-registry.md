---
title: "Trait nova-creator-registry"
draft: true
---
```

;; nova-creator-registry.clar
;; Verified creators
;; CLARITY VERSION: 2

(define-map creators
    principal
    {
        name: (string-utf8 64),
        verified: bool
    }
)

(define-public (register (name (string-utf8 64)))
    (begin
        (map-set creators tx-sender {name: name, verified: false})
        (ok true)
    )
)

(define-read-only (is-verified (user principal))
    (default-to false (get verified (map-get? creators user)))
)

```
