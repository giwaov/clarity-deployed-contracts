;; ---------------------------------------------------------
;; Role Manager
;; Manages admin permissions
;; ---------------------------------------------------------

(define-constant OWNER tx-sender)
(define-map admins principal bool)


;; Owner is admin by default
(map-set admins OWNER true)


;; Adds a new admin (admin-only)
(define-public (add-admin (user principal))
    (if (default-to false (map-get? admins tx-sender))
        (begin
            (map-set admins user true)
            (ok true)
        )
        (err u403)
    )
)


;; Checks admin status
(define-read-only (is-admin (user principal))
    (default-to false (map-get? admins user))
)