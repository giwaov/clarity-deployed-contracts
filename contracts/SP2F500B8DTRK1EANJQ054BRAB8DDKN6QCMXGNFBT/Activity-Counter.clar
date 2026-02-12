
;; Activity Counter
;; A simple contract to increment a counter for on-chain activity

(define-data-var counter uint u0)

(define-read-only (get-counter)
    (ok (var-get counter))
)

(define-public (increment)
    (begin
        (var-set counter (+ (var-get counter) u1))
        (ok (var-get counter))
    )
)
