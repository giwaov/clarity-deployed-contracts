(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))

(define-map mining-sites
  uint
  {
    operator: principal,
    location: (string-ascii 256),
    estimated-reserves: uint,
    extraction-rate: uint,
    geological-survey: (string-ascii 64),
    assessment-date: uint,
    viable: bool
  })

(define-map drilling-operations
  {site-id: uint, operation-id: uint}
  {depth: uint, oil-quality: uint, flow-rate: uint, status: (string-ascii 32)})

(define-data-var next-site-id uint u0)

(define-read-only (get-site (site-id uint))
  (ok (map-get? mining-sites site-id)))

(define-public (register-site (location (string-ascii 256)) (reserves uint) (rate uint) (survey (string-ascii 64)))
  (let ((site-id (var-get next-site-id)))
    (map-set mining-sites site-id
      {operator: tx-sender, location: location, estimated-reserves: reserves,
       extraction-rate: rate, geological-survey: survey, assessment-date: stacks-block-height, viable: false})
    (var-set next-site-id (+ site-id u1))
    (ok site-id)))

(define-public (assess-viability (site-id uint) (viable bool))
  (let ((site (unwrap! (map-get? mining-sites site-id) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set mining-sites site-id (merge site {viable: viable})))))

(define-public (log-drilling (site-id uint) (op-id uint) (depth uint) (quality uint) (flow uint))
  (begin
    (asserts! (is-some (map-get? mining-sites site-id)) err-not-found)
    (ok (map-set drilling-operations {site-id: site-id, operation-id: op-id}
      {depth: depth, oil-quality: quality, flow-rate: flow, status: "active"}))))
