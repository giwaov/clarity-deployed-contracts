(define-data-var current-message (string-ascii 256) "")

(define-public (post-message (msg (string-ascii 256)))
    (begin
        (var-set current-message msg)
        (ok true)
    )
)

(define-read-only (get-message)
    (ok (var-get current-message))
)
