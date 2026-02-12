
;; nova-reputation-score.clar
;; Non-transferable score for governance
;; CLARITY VERSION: 2

(define-map scores principal uint)

(define-public (mint-reputation (user principal) (amount uint))
    (begin
        ;; Only admin can mint (omitted)
        (map-set scores user (+ (default-to u0 (map-get? scores user)) amount))
        (ok true)
    )
)

(define-public (burn-reputation (user principal) (amount uint))
    (let ((current (default-to u0 (map-get? scores user))))
        (asserts! (>= current amount) (err u100))
        (map-set scores user (- current amount))
        (ok true)
    )
)

(define-read-only (get-score (user principal))
    (default-to u0 (map-get? scores user))
)
