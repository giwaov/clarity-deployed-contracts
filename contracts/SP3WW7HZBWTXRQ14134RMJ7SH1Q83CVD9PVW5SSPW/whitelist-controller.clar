;; Whitelist Controller

(define-constant contract-owner tx-sender)

(define-map whitelist principal bool)

(define-public (add-to-whitelist (user principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err u100))
    (map-set whitelist user true)
    (ok true)
  )
)

(define-read-only (is-whitelisted (user principal))
  (default-to false (map-get? whitelist user))
)
