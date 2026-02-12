(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))

(define-map oil-shipments
  uint
  {
    supplier: principal,
    origin: (string-ascii 128),
    destination: (string-ascii 128),
    volume-barrels: uint,
    oil-grade: (string-ascii 32),
    shipment-date: uint,
    status: (string-ascii 32)
  })

(define-map supply-checkpoints
  {shipment-id: uint, checkpoint: (string-ascii 128)}
  {timestamp: uint, verified: bool})

(define-data-var next-shipment-id uint u0)

(define-read-only (get-shipment (shipment-id uint))
  (ok (map-get? oil-shipments shipment-id)))

(define-public (create-shipment (origin (string-ascii 128)) (dest (string-ascii 128)) (volume uint) (grade (string-ascii 32)))
  (let ((shipment-id (var-get next-shipment-id)))
    (map-set oil-shipments shipment-id
      {supplier: tx-sender, origin: origin, destination: dest,
       volume-barrels: volume, oil-grade: grade, shipment-date: stacks-block-height, status: "in-transit"})
    (var-set next-shipment-id (+ shipment-id u1))
    (ok shipment-id)))

(define-public (update-checkpoint (shipment-id uint) (checkpoint (string-ascii 128)))
  (begin
    (asserts! (is-some (map-get? oil-shipments shipment-id)) err-not-found)
    (ok (map-set supply-checkpoints {shipment-id: shipment-id, checkpoint: checkpoint}
      {timestamp: stacks-block-height, verified: true}))))

(define-public (complete-delivery (shipment-id uint))
  (let ((shipment (unwrap! (map-get? oil-shipments shipment-id) err-not-found)))
    (ok (map-set oil-shipments shipment-id (merge shipment {status: "delivered"})))))
