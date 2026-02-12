---
title: "Trait nova-blacklist-manager"
draft: true
---
```

;; nova-blacklist-manager.clar
;; Blocked users
;; CLARITY VERSION: 2

(define-map blacklist principal bool)

(define-public (block-user (user principal))
    (begin
        (map-set blacklist user true)
        (ok true)
    )
)

(define-read-only (is-blacklisted (user principal))
    (default-to false (map-get? blacklist user))
)

```
