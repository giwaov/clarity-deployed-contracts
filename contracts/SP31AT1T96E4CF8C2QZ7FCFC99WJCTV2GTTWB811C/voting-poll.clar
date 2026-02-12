(define-map votes principal bool)
(define-data-var yes-votes uint u0)
(define-data-var no-votes uint u0)

(define-public (vote (choice bool))
    (begin
        (asserts! (is-none (map-get? votes tx-sender)) (err u403))
        (map-set votes tx-sender choice)
        (if choice
            (var-set yes-votes (+ (var-get yes-votes) u1))
            (var-set no-votes (+ (var-get no-votes) u1))
        )
        (ok true)
    )
)

(define-read-only (get-results)
    (ok {yes: (var-get yes-votes), no: (var-get no-votes)})
)
