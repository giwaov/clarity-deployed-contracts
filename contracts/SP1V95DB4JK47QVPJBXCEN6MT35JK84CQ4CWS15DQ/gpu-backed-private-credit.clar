(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-loan-defaulted (err u105))
(define-constant err-insufficient-collateral (err u106))

(define-data-var loan-nonce uint u0)

(define-map gpu-cluster-assets
  uint
  {
    owner: principal,
    cluster-specs-hash: (buff 32),
    total-compute-units: uint,
    market-value: uint,
    utilization-rate: uint,
    verified: bool,
    active: bool
  }
)

(define-map private-credit-loans
  uint
  {
    borrower: principal,
    lender: principal,
    cluster-id: uint,
    loan-amount: uint,
    interest-rate: uint,
    collateral-value: uint,
    ltv-ratio: uint,
    outstanding-balance: uint,
    loan-start: uint,
    loan-maturity: uint,
    repaid: bool,
    defaulted: bool
  }
)

(define-map revenue-sharing
  {loan-id: uint, period-id: uint}
  {
    revenue-generated: uint,
    lender-share: uint,
    borrower-share: uint,
    distribution-block: uint,
    distributed: bool
  }
)

(define-map owner-clusters principal (list 50 uint))
(define-map borrower-loans principal (list 50 uint))
(define-map period-count uint uint)

(define-public (register-gpu-cluster (cluster-specs-hash (buff 32)) (total-compute-units uint) (market-value uint))
  (let
    (
      (cluster-id (+ (var-get loan-nonce) u1))
    )
    (asserts! (> total-compute-units u0) err-invalid-amount)
    (asserts! (> market-value u0) err-invalid-amount)
    (map-set gpu-cluster-assets cluster-id
      {
        owner: tx-sender,
        cluster-specs-hash: cluster-specs-hash,
        total-compute-units: total-compute-units,
        market-value: market-value,
        utilization-rate: u0,
        verified: false,
        active: true
      }
    )
    (map-set owner-clusters tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? owner-clusters tx-sender)) cluster-id) u50)))
    (ok cluster-id)
  )
)

(define-public (verify-cluster (cluster-id uint))
  (let
    (
      (cluster (unwrap! (map-get? gpu-cluster-assets cluster-id) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set gpu-cluster-assets cluster-id (merge cluster {verified: true}))
    (ok true)
  )
)

(define-public (request-private-credit (lender principal) (cluster-id uint) (loan-amount uint) (interest-rate uint) (duration-blocks uint))
  (let
    (
      (cluster (unwrap! (map-get? gpu-cluster-assets cluster-id) err-not-found))
      (loan-id (+ (var-get loan-nonce) u1))
      (ltv (/ (* loan-amount u10000) (get market-value cluster)))
    )
    (asserts! (is-eq tx-sender (get owner cluster)) err-unauthorized)
    (asserts! (get verified cluster) err-not-found)
    (asserts! (get active cluster) err-not-found)
    (asserts! (<= ltv u7000) err-insufficient-collateral)
    (map-set private-credit-loans loan-id
      {
        borrower: tx-sender,
        lender: lender,
        cluster-id: cluster-id,
        loan-amount: loan-amount,
        interest-rate: interest-rate,
        collateral-value: (get market-value cluster),
        ltv-ratio: ltv,
        outstanding-balance: loan-amount,
        loan-start: stacks-block-height,
        loan-maturity: (+ stacks-block-height duration-blocks),
        repaid: false,
        defaulted: false
      }
    )
    (map-set period-count loan-id u0)
    (map-set borrower-loans tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? borrower-loans tx-sender)) loan-id) u50)))
    (var-set loan-nonce loan-id)
    (ok loan-id)
  )
)

(define-public (fund-loan (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? private-credit-loans loan-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get lender loan)) err-unauthorized)
    (try! (stx-transfer? (get loan-amount loan) tx-sender (get borrower loan)))
    (ok true)
  )
)

(define-public (distribute-revenue (loan-id uint) (revenue-generated uint))
  (let
    (
      (loan (unwrap! (map-get? private-credit-loans loan-id) err-not-found))
      (period-id (+ (default-to u0 (map-get? period-count loan-id)) u1))
      (lender-share (/ (* revenue-generated (get interest-rate loan)) u10000))
      (borrower-share (- revenue-generated lender-share))
    )
    (asserts! (is-eq tx-sender (get borrower loan)) err-unauthorized)
    (asserts! (not (get defaulted loan)) err-loan-defaulted)
    (try! (stx-transfer? lender-share tx-sender (get lender loan)))
    (map-set revenue-sharing {loan-id: loan-id, period-id: period-id}
      {
        revenue-generated: revenue-generated,
        lender-share: lender-share,
        borrower-share: borrower-share,
        distribution-block: stacks-block-height,
        distributed: true
      }
    )
    (map-set period-count loan-id period-id)
    (ok true)
  )
)

(define-public (repay-loan (loan-id uint) (amount uint))
  (let
    (
      (loan (unwrap! (map-get? private-credit-loans loan-id) err-not-found))
      (new-balance (if (>= amount (get outstanding-balance loan)) u0 (- (get outstanding-balance loan) amount)))
    )
    (asserts! (is-eq tx-sender (get borrower loan)) err-unauthorized)
    (asserts! (not (get repaid loan)) err-already-exists)
    (asserts! (not (get defaulted loan)) err-loan-defaulted)
    (try! (stx-transfer? amount tx-sender (get lender loan)))
    (map-set private-credit-loans loan-id (merge loan {
      outstanding-balance: new-balance,
      repaid: (is-eq new-balance u0)
    }))
    (ok true)
  )
)

(define-public (mark-default (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? private-credit-loans loan-id) err-not-found))
      (cluster (unwrap! (map-get? gpu-cluster-assets (get cluster-id loan)) err-not-found))
    )
    (asserts! (is-eq tx-sender (get lender loan)) err-unauthorized)
    (asserts! (> stacks-block-height (get loan-maturity loan)) err-not-found)
    (asserts! (> (get outstanding-balance loan) u0) err-invalid-amount)
    (map-set private-credit-loans loan-id (merge loan {defaulted: true}))
    (map-set gpu-cluster-assets (get cluster-id loan) (merge cluster {
      owner: (get lender loan),
      active: false
    }))
    (ok true)
  )
)

(define-public (update-cluster-valuation (cluster-id uint) (new-value uint))
  (let
    (
      (cluster (unwrap! (map-get? gpu-cluster-assets cluster-id) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set gpu-cluster-assets cluster-id (merge cluster {market-value: new-value}))
    (ok true)
  )
)

(define-read-only (get-gpu-cluster (cluster-id uint))
  (ok (map-get? gpu-cluster-assets cluster-id))
)

(define-read-only (get-loan (loan-id uint))
  (ok (map-get? private-credit-loans loan-id))
)

(define-read-only (get-revenue-sharing (loan-id uint) (period-id uint))
  (ok (map-get? revenue-sharing {loan-id: loan-id, period-id: period-id}))
)

(define-read-only (get-owner-clusters (owner principal))
  (ok (map-get? owner-clusters owner))
)

(define-read-only (get-borrower-loans (borrower principal))
  (ok (map-get? borrower-loans borrower))
)
