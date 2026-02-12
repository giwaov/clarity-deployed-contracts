(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

(define-data-var contract-owner principal tx-sender)
(define-data-var cmo principal tx-sender)

(define-map marketing-campaigns uint {name: (string-utf8 200), channel: (string-ascii 30), budget: uint, start-block: uint, end-block: uint, roi: uint, active: bool})
(define-map brand-assets (string-ascii 50) {asset-type: (string-ascii 30), value: uint, approved: bool})
(define-map customer-segments (string-ascii 50) {size: uint, ltv: uint, acquisition-cost: uint, active: bool})
(define-map marketing-metrics {campaign-id: uint, metric-type: (string-ascii 30)} uint)
(define-data-var campaign-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-cmo) (var-get cmo))

(define-read-only (get-campaign (campaign-id uint))
  (map-get? marketing-campaigns campaign-id))

(define-read-only (get-brand-asset (asset-id (string-ascii 50)))
  (map-get? brand-assets asset-id))

(define-read-only (get-customer-segment (segment-id (string-ascii 50)))
  (map-get? customer-segments segment-id))

(define-read-only (get-metric (campaign-id uint) (metric-type (string-ascii 30)))
  (map-get? marketing-metrics {campaign-id: campaign-id, metric-type: metric-type}))

(define-public (set-cmo (new-cmo principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set cmo new-cmo))))

(define-public (launch-campaign (name (string-utf8 200)) (channel (string-ascii 30)) (budget uint) (duration uint))
  (let ((campaign-id (+ (var-get campaign-count) u1)))
    (asserts! (is-eq tx-sender (var-get cmo)) ERR_UNAUTHORIZED)
    (asserts! (> budget u0) ERR_INVALID_PARAMS)
    (map-set marketing-campaigns campaign-id {name: name, channel: channel, budget: budget, start-block: stacks-block-height, end-block: (+ stacks-block-height duration), roi: u0, active: true})
    (var-set campaign-count campaign-id)
    (ok campaign-id)))

(define-public (update-campaign-roi (campaign-id uint) (roi uint))
  (let ((campaign (unwrap! (map-get? marketing-campaigns campaign-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get cmo)) ERR_UNAUTHORIZED)
    (ok (map-set marketing-campaigns campaign-id (merge campaign {roi: roi})))))

(define-public (pause-campaign (campaign-id uint))
  (let ((campaign (unwrap! (map-get? marketing-campaigns campaign-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get cmo)) ERR_UNAUTHORIZED)
    (asserts! (get active campaign) ERR_INVALID_PARAMS)
    (ok (map-set marketing-campaigns campaign-id (merge campaign {active: false})))))

(define-public (register-brand-asset (asset-id (string-ascii 50)) (asset-type (string-ascii 30)) (value uint))
  (begin
    (asserts! (is-eq tx-sender (var-get cmo)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? brand-assets asset-id)) ERR_ALREADY_EXISTS)
    (asserts! (> value u0) ERR_INVALID_PARAMS)
    (ok (map-set brand-assets asset-id {asset-type: asset-type, value: value, approved: true}))))

(define-public (update-asset-value (asset-id (string-ascii 50)) (new-value uint))
  (let ((asset (unwrap! (map-get? brand-assets asset-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get cmo)) ERR_UNAUTHORIZED)
    (asserts! (> new-value u0) ERR_INVALID_PARAMS)
    (ok (map-set brand-assets asset-id (merge asset {value: new-value})))))

(define-public (define-customer-segment (segment-id (string-ascii 50)) (size uint) (ltv uint) (acquisition-cost uint))
  (begin
    (asserts! (is-eq tx-sender (var-get cmo)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? customer-segments segment-id)) ERR_ALREADY_EXISTS)
    (asserts! (and (> size u0) (> ltv u0)) ERR_INVALID_PARAMS)
    (ok (map-set customer-segments segment-id {size: size, ltv: ltv, acquisition-cost: acquisition-cost, active: true}))))

(define-public (update-segment-metrics (segment-id (string-ascii 50)) (new-size uint) (new-ltv uint))
  (let ((segment (unwrap! (map-get? customer-segments segment-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get cmo)) ERR_UNAUTHORIZED)
    (asserts! (and (> new-size u0) (> new-ltv u0)) ERR_INVALID_PARAMS)
    (ok (map-set customer-segments segment-id (merge segment {size: new-size, ltv: new-ltv})))))

(define-public (record-metric (campaign-id uint) (metric-type (string-ascii 30)) (value uint))
  (begin
    (asserts! (is-eq tx-sender (var-get cmo)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? marketing-campaigns campaign-id)) ERR_NOT_FOUND)
    (ok (map-set marketing-metrics {campaign-id: campaign-id, metric-type: metric-type} value))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
