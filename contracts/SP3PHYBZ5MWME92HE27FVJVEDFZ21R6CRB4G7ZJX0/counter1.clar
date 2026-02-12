;; Simple Counter Contract
(define-data-var count uint u0)

(define-read-only (get-count)
    (ok (var-get count))
)

(define-public (increment)
    (begin
        (var-set count (+ (var-get count) u1))
        (ok (var-get count))
    )
)