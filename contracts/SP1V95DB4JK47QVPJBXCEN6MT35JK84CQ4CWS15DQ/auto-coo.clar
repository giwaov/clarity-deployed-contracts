(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

(define-data-var contract-owner principal tx-sender)
(define-data-var coo principal tx-sender)

(define-map operational-processes uint {name: (string-utf8 200), department: (string-ascii 50), efficiency: uint, cost: uint, status: (string-ascii 20)})
(define-map supply-chain-vendors principal {vendor-name: (string-ascii 100), category: (string-ascii 50), rating: uint, active: bool})
(define-map inventory-items (string-ascii 50) {quantity: uint, reorder-level: uint, unit-cost: uint, last-updated: uint})
(define-map kpi-metrics {department: (string-ascii 50), metric: (string-ascii 30), period: uint} uint)
(define-data-var process-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-coo) (var-get coo))

(define-read-only (get-operational-process (process-id uint))
  (map-get? operational-processes process-id))

(define-read-only (get-vendor (vendor-id principal))
  (map-get? supply-chain-vendors vendor-id))

(define-read-only (get-inventory-item (item-id (string-ascii 50)))
  (map-get? inventory-items item-id))

(define-read-only (get-kpi (department (string-ascii 50)) (metric (string-ascii 30)) (period uint))
  (map-get? kpi-metrics {department: department, metric: metric, period: period}))

(define-public (set-coo (new-coo principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set coo new-coo))))

(define-public (create-process (name (string-utf8 200)) (department (string-ascii 50)) (cost uint))
  (let ((process-id (+ (var-get process-count) u1)))
    (asserts! (is-eq tx-sender (var-get coo)) ERR_UNAUTHORIZED)
    (asserts! (> cost u0) ERR_INVALID_PARAMS)
    (map-set operational-processes process-id {name: name, department: department, efficiency: u0, cost: cost, status: "active"})
    (var-set process-count process-id)
    (ok process-id)))

(define-public (update-process-efficiency (process-id uint) (efficiency uint))
  (let ((process (unwrap! (map-get? operational-processes process-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get coo)) ERR_UNAUTHORIZED)
    (asserts! (<= efficiency u100) ERR_INVALID_PARAMS)
    (ok (map-set operational-processes process-id (merge process {efficiency: efficiency})))))

(define-public (update-process-status (process-id uint) (new-status (string-ascii 20)))
  (let ((process (unwrap! (map-get? operational-processes process-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get coo)) ERR_UNAUTHORIZED)
    (ok (map-set operational-processes process-id (merge process {status: new-status})))))

(define-public (onboard-vendor (vendor-id principal) (vendor-name (string-ascii 100)) (category (string-ascii 50)))
  (begin
    (asserts! (is-eq tx-sender (var-get coo)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? supply-chain-vendors vendor-id)) ERR_ALREADY_EXISTS)
    (ok (map-set supply-chain-vendors vendor-id {vendor-name: vendor-name, category: category, rating: u0, active: true}))))

(define-public (update-vendor-rating (vendor-id principal) (rating uint))
  (let ((vendor (unwrap! (map-get? supply-chain-vendors vendor-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get coo)) ERR_UNAUTHORIZED)
    (asserts! (<= rating u100) ERR_INVALID_PARAMS)
    (ok (map-set supply-chain-vendors vendor-id (merge vendor {rating: rating})))))

(define-public (deactivate-vendor (vendor-id principal))
  (let ((vendor (unwrap! (map-get? supply-chain-vendors vendor-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get coo)) ERR_UNAUTHORIZED)
    (ok (map-set supply-chain-vendors vendor-id (merge vendor {active: false})))))

(define-public (manage-inventory (item-id (string-ascii 50)) (quantity uint) (reorder-level uint) (unit-cost uint))
  (begin
    (asserts! (is-eq tx-sender (var-get coo)) ERR_UNAUTHORIZED)
    (asserts! (> unit-cost u0) ERR_INVALID_PARAMS)
    (ok (map-set inventory-items item-id {quantity: quantity, reorder-level: reorder-level, unit-cost: unit-cost, last-updated: stacks-block-height}))))

(define-public (update-inventory-quantity (item-id (string-ascii 50)) (new-quantity uint))
  (let ((item (unwrap! (map-get? inventory-items item-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get coo)) ERR_UNAUTHORIZED)
    (ok (map-set inventory-items item-id (merge item {quantity: new-quantity, last-updated: stacks-block-height})))))

(define-public (set-kpi (department (string-ascii 50)) (metric (string-ascii 30)) (period uint) (value uint))
  (begin
    (asserts! (is-eq tx-sender (var-get coo)) ERR_UNAUTHORIZED)
    (ok (map-set kpi-metrics {department: department, metric: metric, period: period} value))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
