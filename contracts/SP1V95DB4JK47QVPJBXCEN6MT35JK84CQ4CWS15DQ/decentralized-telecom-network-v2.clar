(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u104))
(define-constant err-provider-offline (err u125))

(define-data-var provider-nonce uint u0)

(define-map telecom-providers
  uint
  {
    operator: principal,
    service-type: (string-ascii 30),
    bandwidth-capacity: uint,
    subscribers: uint,
    revenue-pool: uint,
    quality-score: uint,
    active: bool,
    created-block: uint
  }
)

(define-map infrastructure-nodes
  {provider-id: uint, node-id: uint}
  {
    host: principal,
    node-type: (string-ascii 20),
    bandwidth-contributed: uint,
    location-hash: (buff 32),
    rewards-earned: uint,
    operational: bool
  }
)

(define-map subscriptions
  {provider-id: uint, subscriber: principal}
  {
    plan-type: (string-ascii 20),
    monthly-fee: uint,
    data-allowance: uint,
    data-used: uint,
    start-block: uint,
    active: bool
  }
)

(define-map node-counter uint uint)
(define-map operator-providers principal (list 15 uint))

(define-public (create-provider (service-type (string-ascii 30)) (bandwidth uint) (quality uint))
  (let
    (
      (provider-id (+ (var-get provider-nonce) u1))
    )
    (asserts! (> bandwidth u0) err-invalid-amount)
    (map-set telecom-providers provider-id {
      operator: tx-sender,
      service-type: service-type,
      bandwidth-capacity: bandwidth,
      subscribers: u0,
      revenue-pool: u0,
      quality-score: quality,
      active: true,
      created-block: stacks-block-height
    })
    (map-set node-counter provider-id u0)
    (map-set operator-providers tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? operator-providers tx-sender)) provider-id) u15)))
    (var-set provider-nonce provider-id)
    (ok provider-id)
  )
)

(define-public (add-infrastructure-node (provider-id uint) (node-type (string-ascii 20)) 
                                         (bandwidth uint) (location (buff 32)))
  (let
    (
      (provider (unwrap! (map-get? telecom-providers provider-id) err-not-found))
      (node-id (+ (default-to u0 (map-get? node-counter provider-id)) u1))
    )
    (map-set infrastructure-nodes {provider-id: provider-id, node-id: node-id} {
      host: tx-sender,
      node-type: node-type,
      bandwidth-contributed: bandwidth,
      location-hash: location,
      rewards-earned: u0,
      operational: true
    })
    (map-set node-counter provider-id node-id)
    (map-set telecom-providers provider-id (merge provider {
      bandwidth-capacity: (+ (get bandwidth-capacity provider) bandwidth)
    }))
    (ok node-id)
  )
)

(define-public (subscribe (provider-id uint) (plan (string-ascii 20)) (fee uint) (allowance uint))
  (let
    (
      (provider (unwrap! (map-get? telecom-providers provider-id) err-not-found))
    )
    (asserts! (get active provider) err-provider-offline)
    (try! (stx-transfer? fee tx-sender (get operator provider)))
    (map-set subscriptions {provider-id: provider-id, subscriber: tx-sender} {
      plan-type: plan,
      monthly-fee: fee,
      data-allowance: allowance,
      data-used: u0,
      start-block: stacks-block-height,
      active: true
    })
    (map-set telecom-providers provider-id (merge provider {
      subscribers: (+ (get subscribers provider) u1),
      revenue-pool: (+ (get revenue-pool provider) fee)
    }))
    (ok true)
  )
)

(define-public (use-data (provider-id uint) (amount uint))
  (let
    (
      (subscription (unwrap! (map-get? subscriptions {provider-id: provider-id, subscriber: tx-sender}) err-not-found))
      (new-usage (+ (get data-used subscription) amount))
    )
    (asserts! (get active subscription) err-not-found)
    (asserts! (<= new-usage (get data-allowance subscription)) err-invalid-amount)
    (map-set subscriptions {provider-id: provider-id, subscriber: tx-sender}
      (merge subscription {data-used: new-usage}))
    (ok true)
  )
)

(define-public (reward-node (provider-id uint) (node-id uint) (reward uint))
  (let
    (
      (provider (unwrap! (map-get? telecom-providers provider-id) err-not-found))
      (node (unwrap! (map-get? infrastructure-nodes {provider-id: provider-id, node-id: node-id}) err-not-found))
    )
    (asserts! (is-eq tx-sender (get operator provider)) err-unauthorized)
    (try! (stx-transfer? reward tx-sender (get host node)))
    (map-set infrastructure-nodes {provider-id: provider-id, node-id: node-id}
      (merge node {rewards-earned: (+ (get rewards-earned node) reward)}))
    (ok true)
  )
)

(define-read-only (get-provider (provider-id uint))
  (ok (map-get? telecom-providers provider-id))
)

(define-read-only (get-node (provider-id uint) (node-id uint))
  (ok (map-get? infrastructure-nodes {provider-id: provider-id, node-id: node-id}))
)

(define-read-only (get-subscription (provider-id uint) (subscriber principal))
  (ok (map-get? subscriptions {provider-id: provider-id, subscriber: subscriber}))
)

(define-read-only (get-operator-providers (operator principal))
  (ok (map-get? operator-providers operator))
)

(define-read-only (calculate-data-remaining (provider-id uint) (subscriber principal))
  (let
    (
      (subscription (unwrap-panic (map-get? subscriptions {provider-id: provider-id, subscriber: subscriber})))
    )
    (ok (- (get data-allowance subscription) (get data-used subscription)))
  )
)
