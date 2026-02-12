(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-params (err u103))
(define-constant err-already-claimed (err u104))

(define-map policies
  {policy-id: uint}
  {
    farmer: principal,
    crop-type: (string-ascii 64),
    coverage-amount: uint,
    premium: uint,
    start-height: uint,
    end-height: uint,
    status: (string-ascii 16),
    region: (string-ascii 128)
  }
)

(define-map claims
  {claim-id: uint}
  {
    policy-id: uint,
    loss-amount: uint,
    claim-type: (string-ascii 64),
    evidence-hash: (buff 32),
    status: (string-ascii 16),
    filed-at: uint,
    payout: uint
  }
)

(define-data-var policy-nonce uint u0)
(define-data-var claim-nonce uint u0)
(define-data-var pool-balance uint u0)

(define-read-only (get-policy (policy-id uint))
  (map-get? policies {policy-id: policy-id})
)

(define-read-only (get-claim (claim-id uint))
  (map-get? claims {claim-id: claim-id})
)

(define-public (purchase-policy
  (crop-type (string-ascii 64))
  (coverage-amount uint)
  (premium uint)
  (duration uint)
  (region (string-ascii 128))
)
  (let ((policy-id (var-get policy-nonce)))
    (asserts! (> coverage-amount u0) err-invalid-params)
    (asserts! (> premium u0) err-invalid-params)
    (map-set policies {policy-id: policy-id}
      {
        farmer: tx-sender,
        crop-type: crop-type,
        coverage-amount: coverage-amount,
        premium: premium,
        start-height: stacks-block-height,
        end-height: (+ stacks-block-height duration),
        status: "active",
        region: region
      }
    )
    (var-set pool-balance (+ (var-get pool-balance) premium))
    (var-set policy-nonce (+ policy-id u1))
    (ok policy-id)
  )
)

(define-public (file-claim
  (policy-id uint)
  (loss-amount uint)
  (claim-type (string-ascii 64))
  (evidence-hash (buff 32))
)
  (let (
    (policy (unwrap! (map-get? policies {policy-id: policy-id}) err-not-found))
    (claim-id (var-get claim-nonce))
  )
    (asserts! (is-eq tx-sender (get farmer policy)) err-unauthorized)
    (asserts! (is-eq (get status policy) "active") err-invalid-params)
    (asserts! (< stacks-block-height (get end-height policy)) err-invalid-params)
    (asserts! (<= loss-amount (get coverage-amount policy)) err-invalid-params)
    (map-set claims {claim-id: claim-id}
      {
        policy-id: policy-id,
        loss-amount: loss-amount,
        claim-type: claim-type,
        evidence-hash: evidence-hash,
        status: "pending",
        filed-at: stacks-block-height,
        payout: u0
      }
    )
    (var-set claim-nonce (+ claim-id u1))
    (ok claim-id)
  )
)

(define-public (approve-claim (claim-id uint) (payout-amount uint))
  (let ((claim (unwrap! (map-get? claims {claim-id: claim-id}) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-eq (get status claim) "pending") err-invalid-params)
    (asserts! (<= payout-amount (get loss-amount claim)) err-invalid-params)
    (asserts! (<= payout-amount (var-get pool-balance)) err-invalid-params)
    (var-set pool-balance (- (var-get pool-balance) payout-amount))
    (ok (map-set claims {claim-id: claim-id}
      (merge claim {status: "approved", payout: payout-amount})
    ))
  )
)

(define-public (reject-claim (claim-id uint))
  (let ((claim (unwrap! (map-get? claims {claim-id: claim-id}) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-eq (get status claim) "pending") err-invalid-params)
    (ok (map-set claims {claim-id: claim-id}
      (merge claim {status: "rejected"})
    ))
  )
)
