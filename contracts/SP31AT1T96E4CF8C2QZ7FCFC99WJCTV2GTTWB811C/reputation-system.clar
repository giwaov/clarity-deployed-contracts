(define-map reputation principal int)

(define-public (add-rep (user principal) (val int))
    (let ((current (default-to 0 (map-get? reputation user))))
        (map-set reputation user (+ current val))
        (ok true)
    )
)
