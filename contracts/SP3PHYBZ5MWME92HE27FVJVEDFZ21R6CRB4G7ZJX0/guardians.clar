;; Contract: Trusted Guardians
;; Description: List of friends who can help recover funds.

(define-map trusted-friends principal bool)
(define-constant owner tx-sender)

(define-public (add-friend (friend principal))
    (begin
        (asserts! (is-eq tx-sender owner) (err u401))
        (ok (map-set trusted-friends friend true))
    )
)

(define-read-only (is-trusted (user principal))
    (default-to false (map-get? trusted-friends user))
)