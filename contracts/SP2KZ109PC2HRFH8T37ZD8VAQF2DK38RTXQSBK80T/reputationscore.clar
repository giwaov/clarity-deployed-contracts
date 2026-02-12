;; ReputationScore - Rating system

(define-map scores principal uint)
(define-map has-rated {rater: principal, rated: principal} bool)

(define-constant ERR-ALREADY-RATED (err u100))

(define-public (rate-user (user principal) (points uint))
    (begin
        (asserts! (is-none (map-get? has-rated {rater: tx-sender, rated: user})) ERR-ALREADY-RATED)
        (map-set has-rated {rater: tx-sender, rated: user} true)
        (let ((current-score (default-to u0 (map-get? scores user))))
            (ok (map-set scores user (+ current-score points))))))

(define-read-only (get-score (user principal))
    (ok (default-to u0 (map-get? scores user))))
