(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-dataset-inactive (err u105))

(define-data-var dataset-nonce uint u0)

(define-map datasets
  uint
  {
    provider: principal,
    data-type: (string-ascii 40),
    data-hash: (buff 32),
    metadata-hash: (buff 32),
    price: uint,
    quality-score: uint,
    verification-status: bool,
    total-purchases: uint,
    active: bool
  }
)

(define-map purchases
  {buyer: principal, dataset-id: uint}
  {
    purchase-block: uint,
    access-key-hash: (buff 32),
    reviewed: bool
  }
)

(define-map quality-reviews
  {dataset-id: uint, reviewer: principal}
  {
    score: uint,
    comment-hash: (buff 32),
    verified-usage: bool
  }
)

(define-map provider-datasets principal (list 100 uint))
(define-map dataset-earnings uint uint)

(define-public (list-dataset (data-type (string-ascii 40)) (data-hash (buff 32)) (metadata-hash (buff 32)) (price uint) (quality-score uint))
  (let
    (
      (dataset-id (+ (var-get dataset-nonce) u1))
    )
    (asserts! (> price u0) err-invalid-amount)
    (asserts! (<= quality-score u100) err-invalid-amount)
    (map-set datasets dataset-id
      {
        provider: tx-sender,
        data-type: data-type,
        data-hash: data-hash,
        metadata-hash: metadata-hash,
        price: price,
        quality-score: quality-score,
        verification-status: false,
        total-purchases: u0,
        active: true
      }
    )
    (map-set dataset-earnings dataset-id u0)
    (map-set provider-datasets tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? provider-datasets tx-sender)) dataset-id) u100)))
    (var-set dataset-nonce dataset-id)
    (ok dataset-id)
  )
)

(define-public (purchase-dataset (dataset-id uint) (access-key-hash (buff 32)))
  (let
    (
      (dataset (unwrap! (map-get? datasets dataset-id) err-not-found))
    )
    (asserts! (get active dataset) err-dataset-inactive)
    (asserts! (is-none (map-get? purchases {buyer: tx-sender, dataset-id: dataset-id})) err-already-exists)
    (try! (stx-transfer? (get price dataset) tx-sender (get provider dataset)))
    (map-set purchases {buyer: tx-sender, dataset-id: dataset-id}
      {
        purchase-block: stacks-block-height,
        access-key-hash: access-key-hash,
        reviewed: false
      }
    )
    (map-set datasets dataset-id (merge dataset {
      total-purchases: (+ (get total-purchases dataset) u1)
    }))
    (map-set dataset-earnings dataset-id
      (+ (default-to u0 (map-get? dataset-earnings dataset-id)) (get price dataset)))
    (ok true)
  )
)

(define-public (submit-quality-review (dataset-id uint) (score uint) (comment-hash (buff 32)))
  (let
    (
      (dataset (unwrap! (map-get? datasets dataset-id) err-not-found))
      (purchase (unwrap! (map-get? purchases {buyer: tx-sender, dataset-id: dataset-id}) err-unauthorized))
    )
    (asserts! (<= score u100) err-invalid-amount)
    (asserts! (is-none (map-get? quality-reviews {dataset-id: dataset-id, reviewer: tx-sender})) err-already-exists)
    (map-set quality-reviews {dataset-id: dataset-id, reviewer: tx-sender}
      {
        score: score,
        comment-hash: comment-hash,
        verified-usage: true
      }
    )
    (map-set purchases {buyer: tx-sender, dataset-id: dataset-id} (merge purchase {reviewed: true}))
    (ok true)
  )
)

(define-public (verify-dataset (dataset-id uint))
  (let
    (
      (dataset (unwrap! (map-get? datasets dataset-id) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set datasets dataset-id (merge dataset {verification-status: true}))
    (ok true)
  )
)

(define-public (update-dataset-status (dataset-id uint) (active bool))
  (let
    (
      (dataset (unwrap! (map-get? datasets dataset-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get provider dataset)) err-unauthorized)
    (map-set datasets dataset-id (merge dataset {active: active}))
    (ok true)
  )
)

(define-public (update-dataset-price (dataset-id uint) (new-price uint))
  (let
    (
      (dataset (unwrap! (map-get? datasets dataset-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get provider dataset)) err-unauthorized)
    (asserts! (> new-price u0) err-invalid-amount)
    (map-set datasets dataset-id (merge dataset {price: new-price}))
    (ok true)
  )
)

(define-read-only (get-dataset (dataset-id uint))
  (ok (map-get? datasets dataset-id))
)

(define-read-only (get-purchase (buyer principal) (dataset-id uint))
  (ok (map-get? purchases {buyer: buyer, dataset-id: dataset-id}))
)

(define-read-only (get-quality-review (dataset-id uint) (reviewer principal))
  (ok (map-get? quality-reviews {dataset-id: dataset-id, reviewer: reviewer}))
)

(define-read-only (get-provider-datasets (provider principal))
  (ok (map-get? provider-datasets provider))
)

(define-read-only (get-dataset-earnings (dataset-id uint))
  (ok (map-get? dataset-earnings dataset-id))
)
