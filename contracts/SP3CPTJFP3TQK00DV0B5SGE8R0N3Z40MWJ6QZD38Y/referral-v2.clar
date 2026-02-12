;; referral.clar
;; Chain of referrals

(define-map uplines principal principal)

(define-public (register (upline principal))
    (begin
        (asserts! (is-none (map-get? uplines tx-sender)) (err u100))
        (map-set uplines tx-sender upline)
        (ok true)
    )
)

(define-read-only (get-upline (user principal))
    (map-get? uplines user)
)
