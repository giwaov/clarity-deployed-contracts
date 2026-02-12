
;; Staking Math
;; Helper functions for staking calculations

(define-public (calculate-reward (b uint) (rate uint))
    (ok (* b rate))
)

(define-public (double-stake (amount uint))
    (ok (* amount u2))
)

(define-read-only (calculate-fee (amount uint))
    (ok (/ amount u100))
)
