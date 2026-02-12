---
title: "Trait access-control-srt"
draft: true
---
```
;; Role-based access control contract
(define-map roles {user: principal, role: (string-ascii 32)} bool)
(define-data-var owner principal tx-sender)

(define-read-only (has-role (user principal) (role (string-ascii 32)))
  (default-to false (map-get? roles {user: user, role: role}))
)

(define-public (grant-role (user principal) (role (string-ascii 32)))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err u1))
    (ok (map-set roles {user: user, role: role} true))
  )
)

(define-public (revoke-role (user principal) (role (string-ascii 32)))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err u1))
    (ok (map-delete roles {user: user, role: role}))
  )
)

(define-public (check-role (role (string-ascii 32)))
  (if (has-role tx-sender role)
    (ok true)
    (err u2)
  )
)

```
