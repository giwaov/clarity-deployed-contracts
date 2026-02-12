
;; Daily Metrics
;; Tracks daily usage metrics for the platform

(define-data-var daily-count uint u0)

(define-read-only (get-daily-count)
    (ok (var-get daily-count))
)

(define-public (increment-metric)
    (begin
        (var-set daily-count (+ (var-get daily-count) u1))
        (ok (var-get daily-count))
    )
)
