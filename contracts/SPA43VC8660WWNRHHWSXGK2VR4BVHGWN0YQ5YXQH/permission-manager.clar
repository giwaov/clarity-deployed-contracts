;; permission-manager.clar
;; RBAC system for application modules

(define-map user-roles
    { user: principal, role-id: uint }
    bool
)

(define-public (grant-role (user principal) (role-id uint))
    (begin
        (map-set user-roles { user: user, role-id: role-id } true)
        (ok true)
    )
)

(define-public (revoke-role (user principal) (role-id uint))
    (begin
        (map-delete user-roles { user: user, role-id: role-id })
        (ok true)
    )
)
