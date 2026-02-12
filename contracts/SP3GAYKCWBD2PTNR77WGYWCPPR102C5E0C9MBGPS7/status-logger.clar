;; status-logger.clar
;; A decentralized Twitter bio - anyone can write their status

(define-map UserStatus principal (string-utf8 100))

(define-public (write-status (new-status (string-utf8 100)))
    (begin
        ;; Assert length is valid (must be > 0)
        (asserts! (> (len new-status) u0) (err u100))
        (ok (map-set UserStatus tx-sender new-status))
    )
)

(define-read-only (get-status (user principal))
    (ok (map-get? UserStatus user))
)