---
title: "Trait permission-manager"
draft: true
---
```
;; Permission manager contract
(define-map permissions {user: principal, action: (string-ascii 64)} bool)
(define-data-var admin principal tx-sender)

(define-read-only (has-permission (user principal) (action (string-ascii 64)))
  (default-to false (map-get? permissions {user: user, action: action}))
)

(define-public (grant-permission (user principal) (action (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (ok (map-set permissions {user: user, action: action} true))
  )
)

(define-public (revoke-permission (user principal) (action (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (ok (map-delete permissions {user: user, action: action}))
  )
)

(define-public (check-permission (action (string-ascii 64)))
  (if (has-permission tx-sender action)
    (ok true)
    (err u2)
  )
)

```
