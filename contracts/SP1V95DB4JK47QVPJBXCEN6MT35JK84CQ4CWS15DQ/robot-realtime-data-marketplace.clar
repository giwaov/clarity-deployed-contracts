(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-stream-inactive (err u105))
(define-constant err-subscription-expired (err u106))

(define-data-var stream-nonce uint u0)
(define-data-var subscription-nonce uint u0)

(define-map data-streams
  uint
  {
    provider: principal,
    stream-type: (string-ascii 40),
    data-source: (string-ascii 50),
    price-per-block: uint,
    quality-tier: uint,
    active: bool,
    total-subscribers: uint
  }
)

(define-map subscriptions
  uint
  {
    subscriber: principal,
    stream-id: uint,
    start-block: uint,
    end-block: uint,
    total-paid: uint,
    active: bool
  }
)

(define-map data-packets
  {stream-id: uint, block-height: uint}
  {
    data-hash: (buff 32),
    timestamp: uint,
    verified: bool
  }
)

(define-map provider-streams principal (list 50 uint))
(define-map subscriber-subscriptions principal (list 100 uint))
(define-map stream-earnings uint uint)

(define-public (register-data-stream (stream-type (string-ascii 40)) (data-source (string-ascii 50)) (price-per-block uint) (quality-tier uint))
  (let
    (
      (stream-id (+ (var-get stream-nonce) u1))
    )
    (asserts! (> price-per-block u0) err-invalid-amount)
    (map-set data-streams stream-id
      {
        provider: tx-sender,
        stream-type: stream-type,
        data-source: data-source,
        price-per-block: price-per-block,
        quality-tier: quality-tier,
        active: true,
        total-subscribers: u0
      }
    )
    (map-set stream-earnings stream-id u0)
    (map-set provider-streams tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? provider-streams tx-sender)) stream-id) u50)))
    (var-set stream-nonce stream-id)
    (ok stream-id)
  )
)

(define-public (subscribe-to-stream (stream-id uint) (duration-blocks uint))
  (let
    (
      (stream (unwrap! (map-get? data-streams stream-id) err-not-found))
      (subscription-id (+ (var-get subscription-nonce) u1))
      (total-cost (* (get price-per-block stream) duration-blocks))
    )
    (asserts! (get active stream) err-stream-inactive)
    (asserts! (> duration-blocks u0) err-invalid-amount)
    (try! (stx-transfer? total-cost tx-sender (get provider stream)))
    (map-set subscriptions subscription-id
      {
        subscriber: tx-sender,
        stream-id: stream-id,
        start-block: stacks-block-height,
        end-block: (+ stacks-block-height duration-blocks),
        total-paid: total-cost,
        active: true
      }
    )
    (map-set data-streams stream-id (merge stream {
      total-subscribers: (+ (get total-subscribers stream) u1)
    }))
    (map-set subscriber-subscriptions tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? subscriber-subscriptions tx-sender)) subscription-id) u100)))
    (map-set stream-earnings stream-id
      (+ (default-to u0 (map-get? stream-earnings stream-id)) total-cost))
    (var-set subscription-nonce subscription-id)
    (ok subscription-id)
  )
)

(define-public (publish-data-packet (stream-id uint) (data-hash (buff 32)))
  (let
    (
      (stream (unwrap! (map-get? data-streams stream-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get provider stream)) err-unauthorized)
    (asserts! (get active stream) err-stream-inactive)
    (map-set data-packets {stream-id: stream-id, block-height: stacks-block-height}
      {
        data-hash: data-hash,
        timestamp: stacks-block-height,
        verified: true
      }
    )
    (ok true)
  )
)

(define-public (cancel-subscription (subscription-id uint))
  (let
    (
      (subscription (unwrap! (map-get? subscriptions subscription-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get subscriber subscription)) err-unauthorized)
    (asserts! (get active subscription) err-subscription-expired)
    (map-set subscriptions subscription-id (merge subscription {active: false}))
    (ok true)
  )
)

(define-public (update-stream-status (stream-id uint) (active bool))
  (let
    (
      (stream (unwrap! (map-get? data-streams stream-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get provider stream)) err-unauthorized)
    (map-set data-streams stream-id (merge stream {active: active}))
    (ok true)
  )
)

(define-public (update-stream-price (stream-id uint) (new-price uint))
  (let
    (
      (stream (unwrap! (map-get? data-streams stream-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get provider stream)) err-unauthorized)
    (asserts! (> new-price u0) err-invalid-amount)
    (map-set data-streams stream-id (merge stream {price-per-block: new-price}))
    (ok true)
  )
)

(define-read-only (get-data-stream (stream-id uint))
  (ok (map-get? data-streams stream-id))
)

(define-read-only (get-subscription (subscription-id uint))
  (ok (map-get? subscriptions subscription-id))
)

(define-read-only (get-data-packet (stream-id uint) (height uint))
  (ok (map-get? data-packets {stream-id: stream-id, block-height: height}))
)

(define-read-only (get-provider-streams (provider principal))
  (ok (map-get? provider-streams provider))
)

(define-read-only (get-subscriber-subscriptions (subscriber principal))
  (ok (map-get? subscriber-subscriptions subscriber))
)

(define-read-only (get-stream-earnings (stream-id uint))
  (ok (map-get? stream-earnings stream-id))
)

(define-read-only (is-subscription-active (subscription-id uint))
  (let
    (
      (subscription (unwrap! (map-get? subscriptions subscription-id) err-not-found))
    )
    (ok (and (get active subscription) (<= stacks-block-height (get end-block subscription))))
  )
)
