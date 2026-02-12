---
title: "Trait identity"
draft: true
---
```
;; identity.clar
;; Simple identity verification storage

(define-map identities principal { verification-level: uint, verified-by: principal })
(define-constant ADMIN tx-sender)

(define-public (verify-user (user principal) (level uint))
    (begin
        (asserts! (is-eq tx-sender ADMIN) (err u100))
        (map-set identities user { verification-level: level, verified-by: ADMIN })
        (ok true)
    )
)

(define-read-only (get-identity (user principal))
    (map-get? identities user)
)

(define-read-only (is-verified (user principal))
    (match (map-get? identities user)
        info (> (get verification-level info) u0)
        false
    )
)

```
