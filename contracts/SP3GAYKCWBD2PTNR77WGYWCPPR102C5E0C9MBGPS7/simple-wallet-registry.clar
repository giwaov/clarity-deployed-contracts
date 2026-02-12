;; simple-wallet-registry.clar
(define-map AddressToName principal (string-ascii 50))

(define-public (register-name (name (string-ascii 50)))
    (begin
        (asserts! (> (len name) u0) (err u100))
        (ok (map-set AddressToName tx-sender name))
    )
)

(define-read-only (get-name (user principal))
    (ok (map-get? AddressToName user))
)