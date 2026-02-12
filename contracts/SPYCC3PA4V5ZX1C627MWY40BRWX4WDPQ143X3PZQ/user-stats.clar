;; ---------------------------------------------------------
;; User Stats
;; Tracks completed tasks per user
;; ---------------------------------------------------------

(define-map completed principal uint)


(define-public (increment)
    (let ((count (default-to u0 (map-get? completed tx-sender))))
        (map-set completed tx-sender (+ count u1))
        (ok (+ count u1))
    )
)
