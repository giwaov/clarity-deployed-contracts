;; auth-gate.clar
;; Example service that requires specific permission

(define-map authorized-users principal bool)
(define-constant OWNER tx-sender)

(define-public (authorize (user principal))
    (begin
        (asserts! (is-eq tx-sender OWNER) (err u100))
        (map-set authorized-users user true)
        (ok true)
    )
)

(define-public (restricted-action (data (string-utf8 100)))
    (begin
        (asserts! (default-to false (map-get? authorized-users tx-sender)) (err u101)) ;; ERR_UNAUTHORIZED
        (print data)
        (ok true)
    )
)
