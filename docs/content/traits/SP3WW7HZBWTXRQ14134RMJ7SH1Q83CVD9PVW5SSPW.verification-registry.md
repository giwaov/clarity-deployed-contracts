---
title: "Trait verification-registry"
draft: true
---
```
;; Verification Registry

(define-map verified-users principal bool)

(define-public (verify-user (user principal))
  (begin
    (map-set verified-users user true)
    (ok true)
  )
)

(define-read-only (is-verified (user principal))
  (default-to false (map-get? verified-users user))
)

```
