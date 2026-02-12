(define-map controllers principal bool)
(define-data-var admin principal tx-sender)

(define-public (add-controller (user principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) (err u403))
        (map-set controllers user true)
        (ok true)
    )
)

(define-public (remove-controller (user principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) (err u403))
        (map-delete controllers user)
        (ok true)
    )
)

(define-read-only (is-controller (user principal))
    (ok (default-to false (map-get? controllers user)))
)
