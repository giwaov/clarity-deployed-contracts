;; Multi-Asset Lending Platform
;; Supports lending across multiple asset types

(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-insufficient-collateral (err u101))

(define-data-var supported-assets-count uint u0)
(define-data-var total-tvl uint u0)

(define-map supported-assets (string-ascii 32) { enabled: bool, ltv-ratio: uint, interest-rate: uint })
(define-map user-positions principal { collateral-value: uint, debt-value: uint, health-factor: uint })
(define-map asset-pools (string-ascii 32) { total-supplied: uint, total-borrowed: uint, utilization: uint })

(define-read-only (get-asset-info (asset (string-ascii 32)))
  (map-get? supported-assets asset)
)

(define-read-only (get-user-position (user principal))
  (default-to { collateral-value: u0, debt-value: u0, health-factor: u100 } (map-get? user-positions user))
)

(define-read-only (calculate-health-factor (collateral uint) (debt uint))
  (if (is-eq debt u0) u1000 (/ (* collateral u100) debt))
)

(define-public (add-supported-asset (asset (string-ascii 32)) (ltv uint) (rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (map-set supported-assets asset { enabled: true, ltv-ratio: ltv, interest-rate: rate })
    (var-set supported-assets-count (+ (var-get supported-assets-count) u1))
    (ok true)
  )
)

(define-public (supply-asset (asset (string-ascii 32)) (amount uint))
  (let ((pool (default-to { total-supplied: u0, total-borrowed: u0, utilization: u0 } (map-get? asset-pools asset))))
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set asset-pools asset (merge pool { total-supplied: (+ (get total-supplied pool) amount) }))
    (var-set total-tvl (+ (var-get total-tvl) amount))
    (ok amount)
  )
)

(define-public (borrow-asset (asset (string-ascii 32)) (amount uint))
  (let (
    (user-pos (get-user-position tx-sender))
    (asset-info (unwrap! (map-get? supported-assets asset) (err u102)))
    (max-borrow (/ (* (get collateral-value user-pos) (get ltv-ratio asset-info)) u100))
  )
    (asserts! (get enabled asset-info) (err u103))
    (asserts! (>= max-borrow (+ (get debt-value user-pos) amount)) err-insufficient-collateral)
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (map-set user-positions tx-sender (merge user-pos { debt-value: (+ (get debt-value user-pos) amount) }))
    (ok amount)
  )
)

(define-public (repay-asset (asset (string-ascii 32)) (amount uint))
  (let ((user-pos (get-user-position tx-sender)))
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set user-positions tx-sender (merge user-pos { debt-value: (- (get debt-value user-pos) amount) }))
    (ok amount)
  )
)