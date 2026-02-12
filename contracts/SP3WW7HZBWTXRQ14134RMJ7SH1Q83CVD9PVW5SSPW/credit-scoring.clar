;; Credit Scoring System
;; On-chain credit scoring for DeFi lending

(define-constant contract-owner tx-sender)

(define-map credit-scores principal uint)
(define-map credit-history principal (list 100 uint))
(define-map payment-history principal { on-time: uint, late: uint, defaults: uint })

(define-read-only (get-credit-score (user principal))
  (default-to u300 (map-get? credit-scores user))
)

(define-read-only (get-payment-history (user principal))
  (default-to { on-time: u0, late: u0, defaults: u0 } (map-get? payment-history user))
)

(define-public (update-credit-score (user principal) (score uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err u100))
    (asserts! (and (>= score u300) (<= score u850)) (err u101))
    (map-set credit-scores user score)
    (ok score)
  )
)

(define-public (record-payment (user principal) (payment-type (string-ascii 16)))
  (let ((history (get-payment-history user)))
    (asserts! (is-eq tx-sender contract-owner) (err u100))
    (if (is-eq payment-type "on-time")
      (map-set payment-history user (merge history { on-time: (+ (get on-time history) u1) }))
      (if (is-eq payment-type "late")
        (map-set payment-history user (merge history { late: (+ (get late history) u1) }))
        (map-set payment-history user (merge history { defaults: (+ (get defaults history) u1) }))
      )
    )
    (ok true)
  )
)

(define-public (calculate-risk-premium (user principal))
  (let ((score (get-credit-score user)))
    (if (>= score u750)
      (ok u100)  ;; 1% premium for excellent credit
      (if (>= score u650)
        (ok u300)  ;; 3% premium for good credit
        (ok u800)  ;; 8% premium for poor credit
      )
    )
  )
)