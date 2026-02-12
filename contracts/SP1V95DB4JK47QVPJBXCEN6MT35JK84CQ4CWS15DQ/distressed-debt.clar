(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u104))
(define-constant err-not-distressed (err u114))
(define-constant err-already-acquired (err u115))

(define-data-var asset-nonce uint u0)

(define-map distressed-assets
  uint
  {
    original-debtor: principal,
    current-owner: principal,
    face-value: uint,
    discount-rate: uint,
    acquisition-price: uint,
    recovery-amount: uint,
    distress-type: (string-ascii 30),
    acquired: bool,
    resolved: bool,
    list-block: uint
  }
)

(define-map bids
  {asset-id: uint, bidder: principal}
  {
    bid-amount: uint,
    bid-block: uint,
    accepted: bool
  }
)

(define-map asset-bidders uint (list 50 principal))
(define-map owner-assets principal (list 50 uint))

(define-public (list-distressed-asset (face-value uint) (discount uint) (distress-type (string-ascii 30)))
  (let
    (
      (asset-id (+ (var-get asset-nonce) u1))
    )
    (asserts! (> face-value u0) err-invalid-amount)
    (asserts! (<= discount u100) err-invalid-amount)
    (map-set distressed-assets asset-id {
      original-debtor: tx-sender,
      current-owner: tx-sender,
      face-value: face-value,
      discount-rate: discount,
      acquisition-price: u0,
      recovery-amount: u0,
      distress-type: distress-type,
      acquired: false,
      resolved: false,
      list-block: stacks-block-height
    })
    (map-set owner-assets tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? owner-assets tx-sender)) asset-id) u50)))
    (var-set asset-nonce asset-id)
    (ok asset-id)
  )
)

(define-public (place-bid (asset-id uint) (amount uint))
  (let
    (
      (asset (unwrap! (map-get? distressed-assets asset-id) err-not-found))
    )
    (asserts! (not (get acquired asset)) err-already-acquired)
    (asserts! (> amount u0) err-invalid-amount)
    (map-set bids {asset-id: asset-id, bidder: tx-sender} {
      bid-amount: amount,
      bid-block: stacks-block-height,
      accepted: false
    })
    (map-set asset-bidders asset-id
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? asset-bidders asset-id)) tx-sender) u50)))
    (ok true)
  )
)

(define-public (accept-bid (asset-id uint) (bidder principal))
  (let
    (
      (asset (unwrap! (map-get? distressed-assets asset-id) err-not-found))
      (bid (unwrap! (map-get? bids {asset-id: asset-id, bidder: bidder}) err-not-found))
    )
    (asserts! (is-eq tx-sender (get current-owner asset)) err-unauthorized)
    (asserts! (not (get acquired asset)) err-already-acquired)
    (try! (stx-transfer? (get bid-amount bid) bidder tx-sender))
    (map-set bids {asset-id: asset-id, bidder: bidder} (merge bid {accepted: true}))
    (map-set distressed-assets asset-id (merge asset {
      current-owner: bidder,
      acquisition-price: (get bid-amount bid),
      acquired: true
    }))
    (map-set owner-assets bidder
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? owner-assets bidder)) asset-id) u50)))
    (ok true)
  )
)

(define-public (record-recovery (asset-id uint) (amount uint))
  (let
    (
      (asset (unwrap! (map-get? distressed-assets asset-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get current-owner asset)) err-unauthorized)
    (asserts! (get acquired asset) err-not-distressed)
    (map-set distressed-assets asset-id (merge asset {
      recovery-amount: (+ (get recovery-amount asset) amount),
      resolved: (>= (+ (get recovery-amount asset) amount) (get acquisition-price asset))
    }))
    (ok true)
  )
)

(define-read-only (get-asset (asset-id uint))
  (ok (map-get? distressed-assets asset-id))
)

(define-read-only (get-bid (asset-id uint) (bidder principal))
  (ok (map-get? bids {asset-id: asset-id, bidder: bidder}))
)

(define-read-only (get-owner-assets (owner principal))
  (ok (map-get? owner-assets owner))
)

(define-read-only (calculate-discount-price (asset-id uint))
  (let
    (
      (asset (unwrap-panic (map-get? distressed-assets asset-id)))
      (face (get face-value asset))
      (discount (get discount-rate asset))
    )
    (- face (/ (* face discount) u100))
  )
)

(define-read-only (get-recovery-rate (asset-id uint))
  (let
    (
      (asset (unwrap-panic (map-get? distressed-assets asset-id)))
    )
    (if (> (get acquisition-price asset) u0)
      (ok (/ (* (get recovery-amount asset) u100) (get acquisition-price asset)))
      (ok u0)
    )
  )
)
