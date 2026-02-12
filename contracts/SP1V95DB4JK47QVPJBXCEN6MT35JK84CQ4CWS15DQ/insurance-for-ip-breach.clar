(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-policy-expired (err u105))
(define-constant err-claim-denied (err u106))

(define-data-var policy-nonce uint u0)
(define-data-var claim-nonce uint u0)

(define-map insurance-policies
  uint
  {
    insured: principal,
    ip-id-hash: (buff 32),
    coverage-amount: uint,
    premium-amount: uint,
    policy-start: uint,
    policy-end: uint,
    active: bool,
    claims-filed: uint
  }
)

(define-map breach-claims
  uint
  {
    policy-id: uint,
    claimant: principal,
    breach-evidence-hash: (buff 32),
    claimed-amount: uint,
    filing-block: uint,
    status: (string-ascii 20),
    payout-amount: uint,
    processed: bool
  }
)

(define-map claim-assessments
  uint
  {
    assessor: principal,
    verdict: (string-ascii 20),
    assessment-hash: (buff 32),
    assessed-at: uint
  }
)

(define-map insured-policies principal (list 50 uint))
(define-map policy-claims uint (list 20 uint))

(define-public (purchase-policy (ip-id-hash (buff 32)) (coverage-amount uint) (premium-amount uint) (duration-blocks uint))
  (let
    (
      (policy-id (+ (var-get policy-nonce) u1))
    )
    (asserts! (> coverage-amount u0) err-invalid-amount)
    (asserts! (> premium-amount u0) err-invalid-amount)
    (try! (stx-transfer? premium-amount tx-sender (as-contract tx-sender)))
    (map-set insurance-policies policy-id
      {
        insured: tx-sender,
        ip-id-hash: ip-id-hash,
        coverage-amount: coverage-amount,
        premium-amount: premium-amount,
        policy-start: stacks-block-height,
        policy-end: (+ stacks-block-height duration-blocks),
        active: true,
        claims-filed: u0
      }
    )
    (map-set insured-policies tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? insured-policies tx-sender)) policy-id) u50)))
    (var-set policy-nonce policy-id)
    (ok policy-id)
  )
)

(define-public (file-breach-claim (policy-id uint) (breach-evidence-hash (buff 32)) (claimed-amount uint))
  (let
    (
      (policy (unwrap! (map-get? insurance-policies policy-id) err-not-found))
      (claim-id (+ (var-get claim-nonce) u1))
    )
    (asserts! (is-eq tx-sender (get insured policy)) err-unauthorized)
    (asserts! (get active policy) err-policy-expired)
    (asserts! (<= stacks-block-height (get policy-end policy)) err-policy-expired)
    (asserts! (<= claimed-amount (get coverage-amount policy)) err-invalid-amount)
    (map-set breach-claims claim-id
      {
        policy-id: policy-id,
        claimant: tx-sender,
        breach-evidence-hash: breach-evidence-hash,
        claimed-amount: claimed-amount,
        filing-block: stacks-block-height,
        status: "pending",
        payout-amount: u0,
        processed: false
      }
    )
    (map-set insurance-policies policy-id (merge policy {
      claims-filed: (+ (get claims-filed policy) u1)
    }))
    (map-set policy-claims policy-id
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? policy-claims policy-id)) claim-id) u20)))
    (var-set claim-nonce claim-id)
    (ok claim-id)
  )
)

(define-public (assess-claim (claim-id uint) (verdict (string-ascii 20)) (assessment-hash (buff 32)))
  (let
    (
      (claim (unwrap! (map-get? breach-claims claim-id) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (get processed claim)) err-already-exists)
    (map-set claim-assessments claim-id
      {
        assessor: tx-sender,
        verdict: verdict,
        assessment-hash: assessment-hash,
        assessed-at: stacks-block-height
      }
    )
    (ok true)
  )
)

(define-public (approve-claim (claim-id uint) (payout-amount uint))
  (let
    (
      (claim (unwrap! (map-get? breach-claims claim-id) err-not-found))
      (policy (unwrap! (map-get? insurance-policies (get policy-id claim)) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (get processed claim)) err-already-exists)
    (asserts! (<= payout-amount (get claimed-amount claim)) err-invalid-amount)
    (try! (as-contract (stx-transfer? payout-amount tx-sender (get claimant claim))))
    (map-set breach-claims claim-id (merge claim {
      status: "approved",
      payout-amount: payout-amount,
      processed: true
    }))
    (ok true)
  )
)

(define-public (deny-claim (claim-id uint))
  (let
    (
      (claim (unwrap! (map-get? breach-claims claim-id) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (get processed claim)) err-already-exists)
    (map-set breach-claims claim-id (merge claim {
      status: "denied",
      processed: true
    }))
    (ok true)
  )
)

(define-public (cancel-policy (policy-id uint))
  (let
    (
      (policy (unwrap! (map-get? insurance-policies policy-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get insured policy)) err-unauthorized)
    (map-set insurance-policies policy-id (merge policy {active: false}))
    (ok true)
  )
)

(define-read-only (get-policy (policy-id uint))
  (ok (map-get? insurance-policies policy-id))
)

(define-read-only (get-claim (claim-id uint))
  (ok (map-get? breach-claims claim-id))
)

(define-read-only (get-claim-assessment (claim-id uint))
  (ok (map-get? claim-assessments claim-id))
)

(define-read-only (get-insured-policies (insured principal))
  (ok (map-get? insured-policies insured))
)

(define-read-only (get-policy-claims (policy-id uint))
  (ok (map-get? policy-claims policy-id))
)
