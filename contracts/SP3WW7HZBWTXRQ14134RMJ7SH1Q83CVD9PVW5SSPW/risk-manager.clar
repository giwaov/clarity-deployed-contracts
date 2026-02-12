;; Risk Manager
;; Manages risk across DeFi positions

(define-constant contract-owner tx-sender)
(define-data-var max-risk-score uint u100)

(define-map position-risks principal uint)

(define-read-only (get-risk-score (user principal))
  (default-to u0 (map-get? position-risks user))
)

(define-public (assess-risk (user principal) (score uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err u100))
    (map-set position-risks user score)
    (ok score)
  )
)

(define-public (is-position-safe (user principal))
  (ok (<= (get-risk-score user) (var-get max-risk-score)))
)
