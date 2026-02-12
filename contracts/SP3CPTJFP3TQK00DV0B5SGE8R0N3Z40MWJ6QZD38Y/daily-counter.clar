;; daily-counter.clar
;; A counter that can only be incremented once every 24 hours (86400 seconds)

(define-data-var count uint u0)
(define-data-var last-increment-time uint u0)

(define-read-only (get-count)
    (var-get count)
)

(define-read-only (get-last-increment-time)
    (var-get last-increment-time)
)

(define-public (increment)
    (let
        (
            (current-time block-height)
            (last-time (var-get last-increment-time))
        )
        (asserts! (>= current-time (+ last-time u144)) (err u100)) ;; ERR_TOO_SOON (approx 1 day in blocks)
        (var-set count (+ (var-get count) u1))
        (var-set last-increment-time current-time)
        (ok (var-get count))
    )
)
