(define-data-var current-version uint u2)

(define-map version-history uint (string-ascii 128))

(define-public (update-version (description (string-ascii 128)))
    (let ((new-version (var-get current-version)))
        (map-set version-history new-version description)
        (var-set current-version (+ new-version u1))
        (ok new-version)
    )
)

(define-read-only (get-current-version)
    (ok (var-get current-version))
)

(define-read-only (get-version-info (version uint))
    (ok (map-get? version-history version))
)
