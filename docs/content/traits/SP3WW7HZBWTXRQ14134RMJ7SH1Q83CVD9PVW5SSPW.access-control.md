---
title: "Trait access-control"
draft: true
---
```
;; Access Control Contract

(define-map access-grants { user: principal, token-id: uint } bool)

(define-read-only (has-access (user principal) (token-id uint))
  (default-to false (map-get? access-grants { user: user, token-id: token-id }))
)

(define-public (grant-access (user principal) (token-id uint))
  (begin
    (map-set access-grants { user: user, token-id: token-id } true)
    (ok true)
  )
)

(define-public (revoke-access (user principal) (token-id uint))
  (begin
    (map-delete access-grants { user: user, token-id: token-id })
    (ok true)
  )
)

```
