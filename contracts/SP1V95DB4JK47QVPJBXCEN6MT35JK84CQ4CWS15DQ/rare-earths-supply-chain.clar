(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))

(define-map rare-earth-mines
  uint
  {
    operator: principal,
    location: (string-ascii 256),
    element-type: (string-ascii 64),
    concentration: uint,
    annual-output: uint,
    licensed: bool
  })

(define-map supply-chain-stages
  {mine-id: uint, stage: (string-ascii 64)}
  {processor: principal, quantity: uint, status: (string-ascii 32), timestamp: uint})

(define-data-var next-mine-id uint u0)

(define-read-only (get-mine (mine-id uint))
  (ok (map-get? rare-earth-mines mine-id)))

(define-public (register-mine (location (string-ascii 256)) (element (string-ascii 64)) (concentration uint) (output uint))
  (let ((mine-id (var-get next-mine-id)))
    (map-set rare-earth-mines mine-id
      {operator: tx-sender, location: location, element-type: element,
       concentration: concentration, annual-output: output, licensed: false})
    (var-set next-mine-id (+ mine-id u1))
    (ok mine-id)))

(define-public (license-mine (mine-id uint))
  (let ((mine (unwrap! (map-get? rare-earth-mines mine-id) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set rare-earth-mines mine-id (merge mine {licensed: true})))))

(define-public (track-supply-stage (mine-id uint) (stage (string-ascii 64)) (processor principal) (quantity uint))
  (begin
    (ok (map-set supply-chain-stages {mine-id: mine-id, stage: stage}
      {processor: processor, quantity: quantity, status: "in-progress", timestamp: stacks-block-height}))))
