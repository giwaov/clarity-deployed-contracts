(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))

(define-map battery-mines
  uint
  {
    operator: principal,
    location: (string-ascii 256),
    material-type: (string-ascii 64),
    annual-capacity: uint,
    extraction-method: (string-ascii 64),
    licensed: bool
  })

(define-map material-production
  {mine-id: uint, batch-id: uint}
  {material: (string-ascii 64), quantity-tonnes: uint, purity: uint, production-date: uint})

(define-data-var next-mine-id uint u0)

(define-read-only (get-mine (mine-id uint))
  (ok (map-get? battery-mines mine-id)))

(define-public (register-mine (location (string-ascii 256)) (material (string-ascii 64)) (capacity uint) (method (string-ascii 64)))
  (let ((mine-id (var-get next-mine-id)))
    (map-set battery-mines mine-id
      {operator: tx-sender, location: location, material-type: material,
       annual-capacity: capacity, extraction-method: method, licensed: false})
    (var-set next-mine-id (+ mine-id u1))
    (ok mine-id)))

(define-public (license-operation (mine-id uint))
  (let ((mine (unwrap! (map-get? battery-mines mine-id) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set battery-mines mine-id (merge mine {licensed: true})))))

(define-public (log-production (mine-id uint) (batch-id uint) (material (string-ascii 64)) (quantity uint) (purity uint))
  (begin
    (asserts! (is-some (map-get? battery-mines mine-id)) err-not-found)
    (ok (map-set material-production {mine-id: mine-id, batch-id: batch-id}
      {material: material, quantity-tonnes: quantity, purity: purity, production-date: stacks-block-height}))))
