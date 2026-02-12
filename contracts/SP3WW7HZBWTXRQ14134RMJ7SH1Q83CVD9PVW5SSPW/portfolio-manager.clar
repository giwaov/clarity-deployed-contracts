;; Portfolio Management System

(define-map user-portfolios principal { total-value: uint, asset-count: uint, risk-score: uint })
(define-map portfolio-assets { user: principal, asset: (string-ascii 32) } uint)

(define-public (create-portfolio)
  (begin
    (map-set user-portfolios tx-sender { total-value: u0, asset-count: u0, risk-score: u50 })
    (ok true)
  )
)

(define-public (add-asset (asset (string-ascii 32)) (amount uint))
  (let ((portfolio (default-to { total-value: u0, asset-count: u0, risk-score: u50 } (map-get? user-portfolios tx-sender))))
    (map-set portfolio-assets { user: tx-sender, asset: asset } amount)
    (map-set user-portfolios tx-sender (merge portfolio { 
      total-value: (+ (get total-value portfolio) amount),
      asset-count: (+ (get asset-count portfolio) u1)
    }))
    (ok true)
  )
)

(define-read-only (get-portfolio (user principal))
  (map-get? user-portfolios user)
)