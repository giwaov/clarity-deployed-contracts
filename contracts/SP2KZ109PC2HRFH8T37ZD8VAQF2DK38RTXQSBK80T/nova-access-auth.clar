
;; nova-access-auth.clar
;; Central registry for Nova Protocol role-based access control (RBAC).
;; CLARITY VERSION: 2

(define-constant ERR-NOT-AUTHORIZED (err u100))

(define-data-var admin principal tx-sender)

(define-map roles
    {role: (string-ascii 32), user: principal}
    bool
)

(define-public (grant-role (role (string-ascii 32)) (user principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
        (map-set roles {role: role, user: user} true)
        (ok true)
    )
)

(define-public (revoke-role (role (string-ascii 32)) (user principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
        (map-set roles {role: role, user: user} false)
        (ok true)
    )
)

(define-read-only (has-role (role (string-ascii 32)) (user principal))
    (default-to false (map-get? roles {role: role, user: user}))
)

(define-public (transfer-admin (new-admin principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
        (var-set admin new-admin)
        (ok true)
    )
)
