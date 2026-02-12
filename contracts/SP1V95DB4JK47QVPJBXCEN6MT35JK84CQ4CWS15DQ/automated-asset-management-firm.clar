(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

(define-data-var contract-owner principal tx-sender)

(define-map investment-portfolios principal {total-aum: uint, allocation-strategy: (string-ascii 50), risk-profile: uint, active: bool})
(define-map asset-holdings {portfolio: principal, asset-id: (string-ascii 50)} {quantity: uint, cost-basis: uint, current-value: uint})
(define-map trading-orders uint {portfolio: principal, asset-id: (string-ascii 50), order-type: (string-ascii 20), quantity: uint, price: uint, executed: bool, timestamp: uint})
(define-map performance-metrics {portfolio: principal, period: uint} {return-percentage: uint, volatility: uint, sharpe-ratio: uint})
(define-data-var order-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-portfolio (portfolio-id principal))
  (map-get? investment-portfolios portfolio-id))

(define-read-only (get-asset-holding (portfolio principal) (asset-id (string-ascii 50)))
  (map-get? asset-holdings {portfolio: portfolio, asset-id: asset-id}))

(define-read-only (get-trading-order (order-id uint))
  (map-get? trading-orders order-id))

(define-read-only (get-performance (portfolio principal) (period uint))
  (map-get? performance-metrics {portfolio: portfolio, period: period}))

(define-public (create-portfolio (allocation-strategy (string-ascii 50)) (risk-profile uint))
  (begin
    (asserts! (is-none (map-get? investment-portfolios tx-sender)) ERR_ALREADY_EXISTS)
    (asserts! (<= risk-profile u10) ERR_INVALID_PARAMS)
    (ok (map-set investment-portfolios tx-sender {total-aum: u0, allocation-strategy: allocation-strategy, risk-profile: risk-profile, active: true}))))

(define-public (add-asset-holding (asset-id (string-ascii 50)) (quantity uint) (cost-basis uint))
  (let ((portfolio (unwrap! (map-get? investment-portfolios tx-sender) ERR_UNAUTHORIZED)))
    (asserts! (get active portfolio) ERR_UNAUTHORIZED)
    (asserts! (and (> quantity u0) (> cost-basis u0)) ERR_INVALID_PARAMS)
    (ok (map-set asset-holdings {portfolio: tx-sender, asset-id: asset-id} {quantity: quantity, cost-basis: cost-basis, current-value: cost-basis}))))

(define-public (update-holding-value (asset-id (string-ascii 50)) (new-value uint))
  (let ((holding (unwrap! (map-get? asset-holdings {portfolio: tx-sender, asset-id: asset-id}) ERR_NOT_FOUND)))
    (asserts! (is-some (map-get? investment-portfolios tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (> new-value u0) ERR_INVALID_PARAMS)
    (ok (map-set asset-holdings {portfolio: tx-sender, asset-id: asset-id} (merge holding {current-value: new-value})))))

(define-public (place-order (asset-id (string-ascii 50)) (order-type (string-ascii 20)) (quantity uint) (price uint))
  (let ((order-id (+ (var-get order-count) u1))
        (portfolio (unwrap! (map-get? investment-portfolios tx-sender) ERR_UNAUTHORIZED)))
    (asserts! (get active portfolio) ERR_UNAUTHORIZED)
    (asserts! (and (> quantity u0) (> price u0)) ERR_INVALID_PARAMS)
    (map-set trading-orders order-id {portfolio: tx-sender, asset-id: asset-id, order-type: order-type, quantity: quantity, price: price, executed: false, timestamp: stacks-block-height})
    (var-set order-count order-id)
    (ok order-id)))

(define-public (execute-order (order-id uint))
  (let ((order (unwrap! (map-get? trading-orders order-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (not (get executed order)) ERR_ALREADY_EXISTS)
    (ok (map-set trading-orders order-id (merge order {executed: true})))))

(define-public (record-performance (period uint) (return-percentage uint) (volatility uint) (sharpe-ratio uint))
  (begin
    (asserts! (is-some (map-get? investment-portfolios tx-sender)) ERR_UNAUTHORIZED)
    (ok (map-set performance-metrics {portfolio: tx-sender, period: period} {return-percentage: return-percentage, volatility: volatility, sharpe-ratio: sharpe-ratio}))))

(define-public (update-aum (new-aum uint))
  (let ((portfolio (unwrap! (map-get? investment-portfolios tx-sender) ERR_NOT_FOUND)))
    (ok (map-set investment-portfolios tx-sender (merge portfolio {total-aum: new-aum})))))

(define-public (deactivate-portfolio)
  (let ((portfolio (unwrap! (map-get? investment-portfolios tx-sender) ERR_NOT_FOUND)))
    (ok (map-set investment-portfolios tx-sender (merge portfolio {active: false})))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
