(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u104))
(define-constant err-node-offline (err u124))

(define-data-var network-nonce uint u0)

(define-map cellular-networks
  uint
  {
    operator: principal,
    network-name: (string-ascii 30),
    total-nodes: uint,
    active-nodes: uint,
    coverage-area: uint,
    data-transferred: uint,
    token-rewards-pool: uint,
    created-block: uint
  }
)

(define-map network-nodes
  {network-id: uint, node-id: uint}
  {
    host: principal,
    location-hash: (buff 32),
    uptime-percentage: uint,
    data-relayed: uint,
    rewards-earned: uint,
    online: bool,
    registered-block: uint
  }
)

(define-map data-sessions
  {network-id: uint, session-id: uint}
  {
    user: principal,
    data-used: uint,
    cost: uint,
    start-block: uint,
    end-block: uint
  }
)

(define-map node-counter uint uint)
(define-map session-counter uint uint)
(define-map operator-networks principal (list 10 uint))

(define-public (create-network (name (string-ascii 30)) (coverage uint) (reward-pool uint))
  (let
    (
      (network-id (+ (var-get network-nonce) u1))
    )
    (map-set cellular-networks network-id {
      operator: tx-sender,
      network-name: name,
      total-nodes: u0,
      active-nodes: u0,
      coverage-area: coverage,
      data-transferred: u0,
      token-rewards-pool: reward-pool,
      created-block: stacks-block-height
    })
    (map-set node-counter network-id u0)
    (map-set session-counter network-id u0)
    (map-set operator-networks tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? operator-networks tx-sender)) network-id) u10)))
    (var-set network-nonce network-id)
    (ok network-id)
  )
)

(define-public (register-node (network-id uint) (location (buff 32)))
  (let
    (
      (network (unwrap! (map-get? cellular-networks network-id) err-not-found))
      (node-id (+ (default-to u0 (map-get? node-counter network-id)) u1))
    )
    (map-set network-nodes {network-id: network-id, node-id: node-id} {
      host: tx-sender,
      location-hash: location,
      uptime-percentage: u100,
      data-relayed: u0,
      rewards-earned: u0,
      online: true,
      registered-block: stacks-block-height
    })
    (map-set node-counter network-id node-id)
    (map-set cellular-networks network-id (merge network {
      total-nodes: (+ (get total-nodes network) u1),
      active-nodes: (+ (get active-nodes network) u1)
    }))
    (ok node-id)
  )
)

(define-public (start-data-session (network-id uint) (data-amount uint) (payment uint))
  (let
    (
      (network (unwrap! (map-get? cellular-networks network-id) err-not-found))
      (session-id (+ (default-to u0 (map-get? session-counter network-id)) u1))
    )
    (try! (stx-transfer? payment tx-sender (get operator network)))
    (map-set data-sessions {network-id: network-id, session-id: session-id} {
      user: tx-sender,
      data-used: data-amount,
      cost: payment,
      start-block: stacks-block-height,
      end-block: u0
    })
    (map-set session-counter network-id session-id)
    (map-set cellular-networks network-id (merge network {
      data-transferred: (+ (get data-transferred network) data-amount)
    }))
    (ok session-id)
  )
)

(define-public (distribute-node-rewards (network-id uint) (node-id uint) (reward uint))
  (let
    (
      (network (unwrap! (map-get? cellular-networks network-id) err-not-found))
      (node (unwrap! (map-get? network-nodes {network-id: network-id, node-id: node-id}) err-not-found))
    )
    (asserts! (is-eq tx-sender (get operator network)) err-unauthorized)
    (asserts! (<= reward (get token-rewards-pool network)) err-invalid-amount)
    (try! (stx-transfer? reward tx-sender (get host node)))
    (map-set network-nodes {network-id: network-id, node-id: node-id}
      (merge node {rewards-earned: (+ (get rewards-earned node) reward)}))
    (map-set cellular-networks network-id (merge network {
      token-rewards-pool: (- (get token-rewards-pool network) reward)
    }))
    (ok true)
  )
)

(define-public (update-node-status (network-id uint) (node-id uint) (online bool) (data-relayed uint))
  (let
    (
      (network (unwrap! (map-get? cellular-networks network-id) err-not-found))
      (node (unwrap! (map-get? network-nodes {network-id: network-id, node-id: node-id}) err-not-found))
    )
    (asserts! (is-eq tx-sender (get operator network)) err-unauthorized)
    (map-set network-nodes {network-id: network-id, node-id: node-id}
      (merge node {online: online, data-relayed: (+ (get data-relayed node) data-relayed)}))
    (ok true)
  )
)

(define-read-only (get-network (network-id uint))
  (ok (map-get? cellular-networks network-id))
)

(define-read-only (get-node (network-id uint) (node-id uint))
  (ok (map-get? network-nodes {network-id: network-id, node-id: node-id}))
)

(define-read-only (get-session (network-id uint) (session-id uint))
  (ok (map-get? data-sessions {network-id: network-id, session-id: session-id}))
)

(define-read-only (get-operator-networks (operator principal))
  (ok (map-get? operator-networks operator))
)

(define-read-only (calculate-network-utilization (network-id uint))
  (let
    (
      (network (unwrap-panic (map-get? cellular-networks network-id)))
      (total (get total-nodes network))
      (active (get active-nodes network))
    )
    (if (> total u0)
      (ok (/ (* active u100) total))
      (ok u0)
    )
  )
)
