;; license-manager.clar
;; Manages software usage licenses

(define-map licenses
    { holder: principal, type: (string-ascii 32) }
    { issued: uint, valid-until: uint }
)

(define-public (issue-license (holder principal) (license-type (string-ascii 32)))
    (begin
        (map-set licenses 
            { holder: holder, type: license-type } 
            { issued: burn-block-height, valid-until: (+ burn-block-height u52560) } ;; ~1 year blocks
        )
        (ok true)
    )
)

(define-read-only (has-license (holder principal) (license-type (string-ascii 32)))
    (is-some (map-get? licenses { holder: holder, type: license-type }))
)
