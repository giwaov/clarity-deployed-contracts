(define-map achievements principal (list 10 uint))

(define-public (award-badge (id uint))
    (let ((current (default-to (list) (map-get? achievements tx-sender))))
        (map-set achievements tx-sender (unwrap-panic (as-max-len? (append current id) u10)))
        (ok true)
    )
)
