(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-trial-inactive (err u105))
(define-constant err-participant-limit-reached (err u106))

(define-data-var trial-nonce uint u0)
(define-data-var data-submission-nonce uint u0)

(define-map clinical-trials
  uint
  {
    sponsor: principal,
    trial-name: (string-ascii 50),
    protocol-hash: (buff 32),
    data-price: uint,
    max-participants: uint,
    current-participants: uint,
    active: bool,
    verified: bool
  }
)

(define-map trial-data-submissions
  uint
  {
    trial-id: uint,
    researcher: principal,
    data-hash: (buff 32),
    participant-count: uint,
    submission-block: uint,
    payment-amount: uint,
    verified: bool
  }
)

(define-map data-purchases
  {buyer: principal, submission-id: uint}
  {
    purchase-block: uint,
    access-key-hash: (buff 32),
    amount-paid: uint
  }
)

(define-map sponsor-trials principal (list 50 uint))
(define-map researcher-submissions principal (list 100 uint))

(define-public (create-clinical-trial (trial-name (string-ascii 50)) (protocol-hash (buff 32)) (data-price uint) (max-participants uint))
  (let
    (
      (trial-id (+ (var-get trial-nonce) u1))
    )
    (asserts! (> data-price u0) err-invalid-amount)
    (asserts! (> max-participants u0) err-invalid-amount)
    (map-set clinical-trials trial-id
      {
        sponsor: tx-sender,
        trial-name: trial-name,
        protocol-hash: protocol-hash,
        data-price: data-price,
        max-participants: max-participants,
        current-participants: u0,
        active: true,
        verified: false
      }
    )
    (map-set sponsor-trials tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? sponsor-trials tx-sender)) trial-id) u50)))
    (var-set trial-nonce trial-id)
    (ok trial-id)
  )
)

(define-public (submit-trial-data (trial-id uint) (data-hash (buff 32)) (participant-count uint))
  (let
    (
      (trial (unwrap! (map-get? clinical-trials trial-id) err-not-found))
      (submission-id (+ (var-get data-submission-nonce) u1))
    )
    (asserts! (get active trial) err-trial-inactive)
    (asserts! (<= (+ (get current-participants trial) participant-count) (get max-participants trial)) err-participant-limit-reached)
    (map-set trial-data-submissions submission-id
      {
        trial-id: trial-id,
        researcher: tx-sender,
        data-hash: data-hash,
        participant-count: participant-count,
        submission-block: stacks-block-height,
        payment-amount: u0,
        verified: false
      }
    )
    (map-set clinical-trials trial-id (merge trial {
      current-participants: (+ (get current-participants trial) participant-count)
    }))
    (map-set researcher-submissions tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? researcher-submissions tx-sender)) submission-id) u100)))
    (var-set data-submission-nonce submission-id)
    (ok submission-id)
  )
)

(define-public (purchase-trial-data (submission-id uint) (access-key-hash (buff 32)))
  (let
    (
      (submission (unwrap! (map-get? trial-data-submissions submission-id) err-not-found))
      (trial (unwrap! (map-get? clinical-trials (get trial-id submission)) err-not-found))
      (price (get data-price trial))
    )
    (asserts! (get verified submission) err-not-found)
    (asserts! (is-none (map-get? data-purchases {buyer: tx-sender, submission-id: submission-id})) err-already-exists)
    (try! (stx-transfer? price tx-sender (get researcher submission)))
    (map-set data-purchases {buyer: tx-sender, submission-id: submission-id}
      {
        purchase-block: stacks-block-height,
        access-key-hash: access-key-hash,
        amount-paid: price
      }
    )
    (map-set trial-data-submissions submission-id (merge submission {
      payment-amount: (+ (get payment-amount submission) price)
    }))
    (ok true)
  )
)

(define-public (verify-trial-data (submission-id uint))
  (let
    (
      (submission (unwrap! (map-get? trial-data-submissions submission-id) err-not-found))
      (trial (unwrap! (map-get? clinical-trials (get trial-id submission)) err-not-found))
    )
    (asserts! (is-eq tx-sender (get sponsor trial)) err-unauthorized)
    (map-set trial-data-submissions submission-id (merge submission {verified: true}))
    (ok true)
  )
)

(define-public (verify-trial (trial-id uint))
  (let
    (
      (trial (unwrap! (map-get? clinical-trials trial-id) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set clinical-trials trial-id (merge trial {verified: true}))
    (ok true)
  )
)

(define-public (update-trial-status (trial-id uint) (active bool))
  (let
    (
      (trial (unwrap! (map-get? clinical-trials trial-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get sponsor trial)) err-unauthorized)
    (map-set clinical-trials trial-id (merge trial {active: active}))
    (ok true)
  )
)

(define-read-only (get-clinical-trial (trial-id uint))
  (ok (map-get? clinical-trials trial-id))
)

(define-read-only (get-trial-data-submission (submission-id uint))
  (ok (map-get? trial-data-submissions submission-id))
)

(define-read-only (get-data-purchase (buyer principal) (submission-id uint))
  (ok (map-get? data-purchases {buyer: buyer, submission-id: submission-id}))
)

(define-read-only (get-sponsor-trials (sponsor principal))
  (ok (map-get? sponsor-trials sponsor))
)

(define-read-only (get-researcher-submissions (researcher principal))
  (ok (map-get? researcher-submissions researcher))
)
