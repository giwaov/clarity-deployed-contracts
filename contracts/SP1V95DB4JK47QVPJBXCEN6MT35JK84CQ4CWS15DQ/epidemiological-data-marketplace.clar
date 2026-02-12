(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-dataset-inactive (err u105))

(define-data-var dataset-nonce uint u0)

(define-map epidemiological-datasets
  uint
  {
    provider: principal,
    dataset-name: (string-ascii 50),
    disease-category: (string-ascii 40),
    data-hash: (buff 32),
    metadata-hash: (buff 32),
    sample-size: uint,
    price: uint,
    anonymized: bool,
    verified: bool,
    active: bool,
    total-purchases: uint
  }
)

(define-map dataset-purchases
  {buyer: principal, dataset-id: uint}
  {
    purchase-block: uint,
    access-key-hash: (buff 32),
    amount-paid: uint,
    usage-type: (string-ascii 30)
  }
)

(define-map data-quality-ratings
  {dataset-id: uint, rater: principal}
  {
    accuracy-score: uint,
    completeness-score: uint,
    timeliness-score: uint,
    comment-hash: (buff 32)
  }
)

(define-map provider-datasets principal (list 100 uint))
(define-map dataset-earnings uint uint)

(define-public (list-epidemiological-dataset (dataset-name (string-ascii 50)) (disease-category (string-ascii 40)) (data-hash (buff 32)) (metadata-hash (buff 32)) (sample-size uint) (price uint) (anonymized bool))
  (let
    (
      (dataset-id (+ (var-get dataset-nonce) u1))
    )
    (asserts! (> price u0) err-invalid-amount)
    (asserts! (> sample-size u0) err-invalid-amount)
    (map-set epidemiological-datasets dataset-id
      {
        provider: tx-sender,
        dataset-name: dataset-name,
        disease-category: disease-category,
        data-hash: data-hash,
        metadata-hash: metadata-hash,
        sample-size: sample-size,
        price: price,
        anonymized: anonymized,
        verified: false,
        active: true,
        total-purchases: u0
      }
    )
    (map-set dataset-earnings dataset-id u0)
    (map-set provider-datasets tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? provider-datasets tx-sender)) dataset-id) u100)))
    (var-set dataset-nonce dataset-id)
    (ok dataset-id)
  )
)

(define-public (purchase-dataset (dataset-id uint) (access-key-hash (buff 32)) (usage-type (string-ascii 30)))
  (let
    (
      (dataset (unwrap! (map-get? epidemiological-datasets dataset-id) err-not-found))
    )
    (asserts! (get active dataset) err-dataset-inactive)
    (asserts! (get verified dataset) err-not-found)
    (asserts! (is-none (map-get? dataset-purchases {buyer: tx-sender, dataset-id: dataset-id})) err-already-exists)
    (try! (stx-transfer? (get price dataset) tx-sender (get provider dataset)))
    (map-set dataset-purchases {buyer: tx-sender, dataset-id: dataset-id}
      {
        purchase-block: stacks-block-height,
        access-key-hash: access-key-hash,
        amount-paid: (get price dataset),
        usage-type: usage-type
      }
    )
    (map-set epidemiological-datasets dataset-id (merge dataset {
      total-purchases: (+ (get total-purchases dataset) u1)
    }))
    (map-set dataset-earnings dataset-id
      (+ (default-to u0 (map-get? dataset-earnings dataset-id)) (get price dataset)))
    (ok true)
  )
)

(define-public (rate-dataset-quality (dataset-id uint) (accuracy-score uint) (completeness-score uint) (timeliness-score uint) (comment-hash (buff 32)))
  (let
    (
      (dataset (unwrap! (map-get? epidemiological-datasets dataset-id) err-not-found))
      (purchase (unwrap! (map-get? dataset-purchases {buyer: tx-sender, dataset-id: dataset-id}) err-unauthorized))
    )
    (asserts! (<= accuracy-score u100) err-invalid-amount)
    (asserts! (<= completeness-score u100) err-invalid-amount)
    (asserts! (<= timeliness-score u100) err-invalid-amount)
    (asserts! (is-none (map-get? data-quality-ratings {dataset-id: dataset-id, rater: tx-sender})) err-already-exists)
    (map-set data-quality-ratings {dataset-id: dataset-id, rater: tx-sender}
      {
        accuracy-score: accuracy-score,
        completeness-score: completeness-score,
        timeliness-score: timeliness-score,
        comment-hash: comment-hash
      }
    )
    (ok true)
  )
)

(define-public (verify-dataset (dataset-id uint))
  (let
    (
      (dataset (unwrap! (map-get? epidemiological-datasets dataset-id) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set epidemiological-datasets dataset-id (merge dataset {verified: true}))
    (ok true)
  )
)

(define-public (update-dataset-status (dataset-id uint) (active bool))
  (let
    (
      (dataset (unwrap! (map-get? epidemiological-datasets dataset-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get provider dataset)) err-unauthorized)
    (map-set epidemiological-datasets dataset-id (merge dataset {active: active}))
    (ok true)
  )
)

(define-public (update-dataset-price (dataset-id uint) (new-price uint))
  (let
    (
      (dataset (unwrap! (map-get? epidemiological-datasets dataset-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get provider dataset)) err-unauthorized)
    (asserts! (> new-price u0) err-invalid-amount)
    (map-set epidemiological-datasets dataset-id (merge dataset {price: new-price}))
    (ok true)
  )
)

(define-read-only (get-dataset (dataset-id uint))
  (ok (map-get? epidemiological-datasets dataset-id))
)

(define-read-only (get-dataset-purchase (buyer principal) (dataset-id uint))
  (ok (map-get? dataset-purchases {buyer: buyer, dataset-id: dataset-id}))
)

(define-read-only (get-quality-rating (dataset-id uint) (rater principal))
  (ok (map-get? data-quality-ratings {dataset-id: dataset-id, rater: rater}))
)

(define-read-only (get-provider-datasets (provider principal))
  (ok (map-get? provider-datasets provider))
)

(define-read-only (get-dataset-earnings (dataset-id uint))
  (ok (map-get? dataset-earnings dataset-id))
)
