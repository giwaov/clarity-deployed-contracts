;; Contract: Private Access Gate
;; Description: Only whitelisted users can enter.

(define-map whitelist principal bool)
(define-constant contract-owner tx-sender)
(define-constant err-forbidden (err u403))

(define-public (add-user (user principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-forbidden)
        (ok (map-set whitelist user true))
    )
)

(define-public (enter-club)
    (begin
        (asserts! (default-to false (map-get? whitelist tx-sender)) err-forbidden)
        (ok "Welcome to the VIP area")
    )
)