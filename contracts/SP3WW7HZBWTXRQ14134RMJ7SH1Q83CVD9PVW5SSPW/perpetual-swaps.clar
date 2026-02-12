;; Perpetual Swaps Contract
;; Enables perpetual futures trading

(define-constant contract-owner tx-sender)
(define-data-var next-position-id uint u1)
(define-data-var funding-rate uint u10) ;; 0.01% funding rate

(define-map positions
  uint
  {
    trader: principal,
    asset: (string-ascii 32),
    size: uint,
    entry-price: uint,
    leverage: uint,
    margin: uint,
    is-long: bool,
    liquidation-price: uint
  }
)

(define-map funding-payments principal int)

(define-read-only (get-position (position-id uint))
  (map-get? positions position-id)
)

(define-read-only (calculate-liquidation-price (entry-price uint) (leverage uint) (is-long bool))
  (if is-long
    (- entry-price (/ entry-price leverage))
    (+ entry-price (/ entry-price leverage))
  )
)

(define-public (open-position (asset (string-ascii 32)) (size uint) (leverage uint) (is-long bool))
  (let (
    (position-id (var-get next-position-id))
    (margin (/ size leverage))
    (entry-price u50000) ;; Mock price
    (liq-price (calculate-liquidation-price entry-price leverage is-long))
  )
    (try! (stx-transfer? margin tx-sender (as-contract tx-sender)))
    (map-set positions position-id {
      trader: tx-sender,
      asset: asset,
      size: size,
      entry-price: entry-price,
      leverage: leverage,
      margin: margin,
      is-long: is-long,
      liquidation-price: liq-price
    })
    (var-set next-position-id (+ position-id u1))
    (ok position-id)
  )
)

(define-public (close-position (position-id uint))
  (let ((position (unwrap! (map-get? positions position-id) (err u100))))
    (asserts! (is-eq tx-sender (get trader position)) (err u101))
    (try! (as-contract (stx-transfer? (get margin position) tx-sender tx-sender)))
    (map-delete positions position-id)
    (ok true)
  )
)

(define-public (pay-funding (position-id uint))
  (let ((position (unwrap! (map-get? positions position-id) (err u100))))
    (let ((funding-amount (/ (* (get size position) (var-get funding-rate)) u10000)))
      (map-set funding-payments (get trader position) 
        (- (default-to 0 (map-get? funding-payments (get trader position))) (to-int funding-amount)))
      (ok funding-amount)
    )
  )
)