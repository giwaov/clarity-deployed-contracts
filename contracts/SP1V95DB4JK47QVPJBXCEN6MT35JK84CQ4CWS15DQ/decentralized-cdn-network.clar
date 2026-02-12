(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-node-inactive (err u105))

(define-data-var node-nonce uint u0)
(define-data-var content-nonce uint u0)

(define-map cdn-nodes
  uint
  {
    operator: principal,
    location-hash: (buff 32),
    bandwidth-capacity: uint,
    storage-capacity: uint,
    stake-amount: uint,
    active: bool,
    total-served: uint,
    reputation-score: uint
  }
)

(define-map cached-content
  uint
  {
    content-hash: (buff 32),
    content-size: uint,
    origin-url-hash: (buff 32),
    cached-at: uint,
    access-count: uint,
    payment-per-access: uint
  }
)

(define-map content-distribution
  {content-id: uint, node-id: uint}
  {
    cached: bool,
    served-count: uint,
    total-earned: uint
  }
)

(define-map operator-nodes principal (list 50 uint))
(define-map node-earnings uint uint)

(define-public (register-cdn-node (location-hash (buff 32)) (bandwidth-capacity uint) (storage-capacity uint) (stake-amount uint))
  (let
    (
      (node-id (+ (var-get node-nonce) u1))
    )
    (asserts! (> stake-amount u0) err-invalid-amount)
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    (map-set cdn-nodes node-id
      {
        operator: tx-sender,
        location-hash: location-hash,
        bandwidth-capacity: bandwidth-capacity,
        storage-capacity: storage-capacity,
        stake-amount: stake-amount,
        active: true,
        total-served: u0,
        reputation-score: u100
      }
    )
    (map-set node-earnings node-id u0)
    (map-set operator-nodes tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? operator-nodes tx-sender)) node-id) u50)))
    (var-set node-nonce node-id)
    (ok node-id)
  )
)

(define-public (cache-content (content-hash (buff 32)) (content-size uint) (origin-url-hash (buff 32)) (payment-per-access uint))
  (let
    (
      (content-id (+ (var-get content-nonce) u1))
    )
    (asserts! (> content-size u0) err-invalid-amount)
    (map-set cached-content content-id
      {
        content-hash: content-hash,
        content-size: content-size,
        origin-url-hash: origin-url-hash,
        cached-at: stacks-block-height,
        access-count: u0,
        payment-per-access: payment-per-access
      }
    )
    (var-set content-nonce content-id)
    (ok content-id)
  )
)

(define-public (distribute-content-to-node (content-id uint) (node-id uint))
  (let
    (
      (content (unwrap! (map-get? cached-content content-id) err-not-found))
      (node (unwrap! (map-get? cdn-nodes node-id) err-not-found))
    )
    (asserts! (get active node) err-node-inactive)
    (asserts! (is-none (map-get? content-distribution {content-id: content-id, node-id: node-id})) err-already-exists)
    (map-set content-distribution {content-id: content-id, node-id: node-id}
      {
        cached: true,
        served-count: u0,
        total-earned: u0
      }
    )
    (ok true)
  )
)

(define-public (serve-content (content-id uint) (node-id uint) (requester principal))
  (let
    (
      (content (unwrap! (map-get? cached-content content-id) err-not-found))
      (node (unwrap! (map-get? cdn-nodes node-id) err-not-found))
      (distribution (unwrap! (map-get? content-distribution {content-id: content-id, node-id: node-id}) err-not-found))
      (payment (get payment-per-access content))
    )
    (asserts! (is-eq tx-sender (get operator node)) err-unauthorized)
    (asserts! (get active node) err-node-inactive)
    (try! (stx-transfer? payment requester (get operator node)))
    (map-set cached-content content-id (merge content {
      access-count: (+ (get access-count content) u1)
    }))
    (map-set content-distribution {content-id: content-id, node-id: node-id} (merge distribution {
      served-count: (+ (get served-count distribution) u1),
      total-earned: (+ (get total-earned distribution) payment)
    }))
    (map-set cdn-nodes node-id (merge node {
      total-served: (+ (get total-served node) u1)
    }))
    (map-set node-earnings node-id
      (+ (default-to u0 (map-get? node-earnings node-id)) payment))
    (ok true)
  )
)

(define-public (update-node-status (node-id uint) (active bool))
  (let
    (
      (node (unwrap! (map-get? cdn-nodes node-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get operator node)) err-unauthorized)
    (map-set cdn-nodes node-id (merge node {active: active}))
    (ok true)
  )
)

(define-public (withdraw-stake (node-id uint))
  (let
    (
      (node (unwrap! (map-get? cdn-nodes node-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get operator node)) err-unauthorized)
    (asserts! (not (get active node)) err-node-inactive)
    (try! (as-contract (stx-transfer? (get stake-amount node) tx-sender (get operator node))))
    (map-set cdn-nodes node-id (merge node {stake-amount: u0}))
    (ok true)
  )
)

(define-read-only (get-cdn-node (node-id uint))
  (ok (map-get? cdn-nodes node-id))
)

(define-read-only (get-cached-content (content-id uint))
  (ok (map-get? cached-content content-id))
)

(define-read-only (get-content-distribution (content-id uint) (node-id uint))
  (ok (map-get? content-distribution {content-id: content-id, node-id: node-id}))
)

(define-read-only (get-operator-nodes (operator principal))
  (ok (map-get? operator-nodes operator))
)

(define-read-only (get-node-earnings (node-id uint))
  (ok (map-get? node-earnings node-id))
)
