(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-insufficient-capacity (err u105))

(define-data-var gpu-nonce uint u0)
(define-data-var job-nonce uint u0)

(define-map gpu-providers
  uint
  {
    provider: principal,
    gpu-model: (string-ascii 30),
    compute-units: uint,
    price-per-unit: uint,
    available-capacity: uint,
    total-capacity: uint,
    stake-amount: uint,
    active: bool,
    total-jobs-completed: uint
  }
)

(define-map compute-jobs
  uint
  {
    requester: principal,
    gpu-provider-id: uint,
    job-type: (string-ascii 30),
    compute-units-required: uint,
    total-payment: uint,
    job-hash: (buff 32),
    start-block: uint,
    completed: bool,
    verified: bool
  }
)

(define-map job-results
  uint
  {
    result-hash: (buff 32),
    completion-block: uint,
    quality-score: uint
  }
)

(define-map provider-jobs uint (list 200 uint))
(define-map provider-earnings uint uint)

(define-public (register-gpu-provider (gpu-model (string-ascii 30)) (compute-units uint) (price-per-unit uint) (stake-amount uint))
  (let
    (
      (gpu-id (+ (var-get gpu-nonce) u1))
    )
    (asserts! (> compute-units u0) err-invalid-amount)
    (asserts! (> price-per-unit u0) err-invalid-amount)
    (asserts! (> stake-amount u0) err-invalid-amount)
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    (map-set gpu-providers gpu-id
      {
        provider: tx-sender,
        gpu-model: gpu-model,
        compute-units: compute-units,
        price-per-unit: price-per-unit,
        available-capacity: compute-units,
        total-capacity: compute-units,
        stake-amount: stake-amount,
        active: true,
        total-jobs-completed: u0
      }
    )
    (map-set provider-earnings gpu-id u0)
    (var-set gpu-nonce gpu-id)
    (ok gpu-id)
  )
)

(define-public (submit-compute-job (gpu-provider-id uint) (job-type (string-ascii 30)) (compute-units-required uint) (job-hash (buff 32)))
  (let
    (
      (provider (unwrap! (map-get? gpu-providers gpu-provider-id) err-not-found))
      (job-id (+ (var-get job-nonce) u1))
      (total-cost (* compute-units-required (get price-per-unit provider)))
    )
    (asserts! (get active provider) err-not-found)
    (asserts! (>= (get available-capacity provider) compute-units-required) err-insufficient-capacity)
    (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
    (map-set compute-jobs job-id
      {
        requester: tx-sender,
        gpu-provider-id: gpu-provider-id,
        job-type: job-type,
        compute-units-required: compute-units-required,
        total-payment: total-cost,
        job-hash: job-hash,
        start-block: stacks-block-height,
        completed: false,
        verified: false
      }
    )
    (map-set gpu-providers gpu-provider-id (merge provider {
      available-capacity: (- (get available-capacity provider) compute-units-required)
    }))
    (map-set provider-jobs gpu-provider-id
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? provider-jobs gpu-provider-id)) job-id) u200)))
    (var-set job-nonce job-id)
    (ok job-id)
  )
)

(define-public (submit-job-result (job-id uint) (result-hash (buff 32)))
  (let
    (
      (job (unwrap! (map-get? compute-jobs job-id) err-not-found))
      (provider (unwrap! (map-get? gpu-providers (get gpu-provider-id job)) err-not-found))
    )
    (asserts! (is-eq tx-sender (get provider provider)) err-unauthorized)
    (asserts! (not (get completed job)) err-already-exists)
    (map-set job-results job-id
      {
        result-hash: result-hash,
        completion-block: stacks-block-height,
        quality-score: u0
      }
    )
    (map-set compute-jobs job-id (merge job {completed: true}))
    (ok true)
  )
)

(define-public (verify-and-pay-job (job-id uint) (quality-score uint))
  (let
    (
      (job (unwrap! (map-get? compute-jobs job-id) err-not-found))
      (provider (unwrap! (map-get? gpu-providers (get gpu-provider-id job)) err-not-found))
    )
    (asserts! (is-eq tx-sender (get requester job)) err-unauthorized)
    (asserts! (get completed job) err-not-found)
    (asserts! (not (get verified job)) err-already-exists)
    (asserts! (<= quality-score u100) err-invalid-amount)
    (try! (as-contract (stx-transfer? (get total-payment job) tx-sender (get provider provider))))
    (map-set compute-jobs job-id (merge job {verified: true}))
    (map-set job-results job-id (merge (unwrap-panic (map-get? job-results job-id)) {quality-score: quality-score}))
    (map-set gpu-providers (get gpu-provider-id job) (merge provider {
      available-capacity: (+ (get available-capacity provider) (get compute-units-required job)),
      total-jobs-completed: (+ (get total-jobs-completed provider) u1)
    }))
    (map-set provider-earnings (get gpu-provider-id job)
      (+ (default-to u0 (map-get? provider-earnings (get gpu-provider-id job))) (get total-payment job)))
    (ok true)
  )
)

(define-public (update-provider-status (gpu-id uint) (active bool))
  (let
    (
      (provider (unwrap! (map-get? gpu-providers gpu-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get provider provider)) err-unauthorized)
    (map-set gpu-providers gpu-id (merge provider {active: active}))
    (ok true)
  )
)

(define-public (withdraw-stake (gpu-id uint))
  (let
    (
      (provider (unwrap! (map-get? gpu-providers gpu-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get provider provider)) err-unauthorized)
    (asserts! (not (get active provider)) err-not-found)
    (try! (as-contract (stx-transfer? (get stake-amount provider) tx-sender (get provider provider))))
    (map-set gpu-providers gpu-id (merge provider {stake-amount: u0}))
    (ok true)
  )
)

(define-read-only (get-gpu-provider (gpu-id uint))
  (ok (map-get? gpu-providers gpu-id))
)

(define-read-only (get-compute-job (job-id uint))
  (ok (map-get? compute-jobs job-id))
)

(define-read-only (get-job-result (job-id uint))
  (ok (map-get? job-results job-id))
)

(define-read-only (get-provider-jobs (gpu-id uint))
  (ok (map-get? provider-jobs gpu-id))
)

(define-read-only (get-provider-earnings (gpu-id uint))
  (ok (map-get? provider-earnings gpu-id))
)
