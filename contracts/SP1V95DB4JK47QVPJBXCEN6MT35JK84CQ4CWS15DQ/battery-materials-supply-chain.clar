(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))

(define-map supply-chain-nodes
  uint
  {
    node-type: (string-ascii 64),
    operator: principal,
    location: (string-ascii 128),
    material-handled: (string-ascii 64),
    capacity: uint,
    active: bool
  })

(define-map material-transfers
  uint
  {
    from-node: uint,
    to-node: uint,
    material: (string-ascii 64),
    quantity: uint,
    transfer-date: uint,
    status: (string-ascii 32)
  })

(define-data-var next-node-id uint u0)
(define-data-var next-transfer-id uint u0)

(define-read-only (get-node (node-id uint))
  (ok (map-get? supply-chain-nodes node-id)))

(define-public (register-node (type (string-ascii 64)) (location (string-ascii 128)) (material (string-ascii 64)) (capacity uint))
  (let ((node-id (var-get next-node-id)))
    (map-set supply-chain-nodes node-id
      {node-type: type, operator: tx-sender, location: location,
       material-handled: material, capacity: capacity, active: true})
    (var-set next-node-id (+ node-id u1))
    (ok node-id)))

(define-public (transfer-material (from uint) (to uint) (material (string-ascii 64)) (quantity uint))
  (let ((transfer-id (var-get next-transfer-id)))
    (asserts! (is-some (map-get? supply-chain-nodes from)) err-not-found)
    (asserts! (is-some (map-get? supply-chain-nodes to)) err-not-found)
    (map-set material-transfers transfer-id
      {from-node: from, to-node: to, material: material,
       quantity: quantity, transfer-date: stacks-block-height, status: "in-transit"})
    (var-set next-transfer-id (+ transfer-id u1))
    (ok transfer-id)))
