---
title: "Trait acl"
draft: true
---
```
;; acl.clar
;; Role-based Access Control

(define-constant ROLE_ADMIN u1)
(define-constant ROLE_MODERATOR u2)
(define-constant ROLE_USER u3)

(define-map user-roles principal uint)
(define-constant SUPER_ADMIN tx-sender)

(define-public (set-role (user principal) (role uint))
    (let
        (
            (caller-role (default-to ROLE_USER (map-get? user-roles tx-sender)))
        )
        ;; Only super admin or admin can set roles
        (asserts! (or (is-eq tx-sender SUPER_ADMIN) (is-eq caller-role ROLE_ADMIN)) (err u100))
        (map-set user-roles user role)
        (ok true)
    )
)

(define-read-only (get-role (user principal))
    (default-to ROLE_USER (map-get? user-roles user))
)

(define-read-only (has-role (user principal) (role uint))
    (is-eq (get-role user) role)
)

```
