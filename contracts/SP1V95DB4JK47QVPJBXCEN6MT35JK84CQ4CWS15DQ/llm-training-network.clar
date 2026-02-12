(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-job-complete (err u105))
(define-constant err-insufficient-stake (err u106))

(define-data-var job-nonce uint u0)
(define-data-var node-nonce uint u0)

(define-map training-jobs
  uint
  {
    requester: principal,
    dataset-hash: (buff 32),
    model-config-hash: (buff 32),
    total-budget: uint,
    remaining-budget: uint,
    min-gpu-compute: uint,
    target-accuracy: uint,
    completed: bool,
    result-hash: (optional (buff 32))
  }
)

(define-map compute-nodes
  uint
  {
    provider: principal,
    gpu-type: (string-ascii 30),
    compute-power: uint,
    stake-amount: uint,
    total-jobs-completed: uint,
    active: bool,
    reputation: uint
  }
)

(define-map job-assignments
  {job-id: uint, node-id: uint}
  {
    assigned-block: uint,
    contribution-weight: uint,
    payment-amount: uint,
    work-verified: bool
  }
)

(define-map provider-nodes principal (list 50 uint))
(define-map node-earnings uint uint)

(define-public (register-compute-node (gpu-type (string-ascii 30)) (compute-power uint) (stake-amount uint))
  (let
    (
      (node-id (+ (var-get node-nonce) u1))
    )
    (asserts! (> stake-amount u0) err-invalid-amount)
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    (map-set compute-nodes node-id
      {
        provider: tx-sender,
        gpu-type: gpu-type,
        compute-power: compute-power,
        stake-amount: stake-amount,
        total-jobs-completed: u0,
        active: true,
        reputation: u100
      }
    )
    (map-set node-earnings node-id u0)
    (map-set provider-nodes tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? provider-nodes tx-sender)) node-id) u50)))
    (var-set node-nonce node-id)
    (ok node-id)
  )
)

(define-public (submit-training-job (dataset-hash (buff 32)) (model-config-hash (buff 32)) (budget uint) (min-gpu-compute uint) (target-accuracy uint))
  (let
    (
      (job-id (+ (var-get job-nonce) u1))
    )
    (asserts! (> budget u0) err-invalid-amount)
    (try! (stx-transfer? budget tx-sender (as-contract tx-sender)))
    (map-set training-jobs job-id
      {
        requester: tx-sender,
        dataset-hash: dataset-hash,
        model-config-hash: model-config-hash,
        total-budget: budget,
        remaining-budget: budget,
        min-gpu-compute: min-gpu-compute,
        target-accuracy: target-accuracy,
        completed: false,
        result-hash: none
      }
    )
    (var-set job-nonce job-id)
    (ok job-id)
  )
)

(define-public (assign-node-to-job (job-id uint) (node-id uint) (contribution-weight uint))
  (let
    (
      (job (unwrap! (map-get? training-jobs job-id) err-not-found))
      (node (unwrap! (map-get? compute-nodes node-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get requester job)) err-unauthorized)
    (asserts! (not (get completed job)) err-job-complete)
    (asserts! (get active node) err-not-found)
    (asserts! (>= (get compute-power node) (get min-gpu-compute job)) err-insufficient-stake)
    (map-set job-assignments {job-id: job-id, node-id: node-id}
      {
        assigned-block: stacks-block-height,
        contribution-weight: contribution-weight,
        payment-amount: u0,
        work-verified: false
      }
    )
    (ok true)
  )
)

(define-public (verify-and-pay-node (job-id uint) (node-id uint) (payment-amount uint))
  (let
    (
      (job (unwrap! (map-get? training-jobs job-id) err-not-found))
      (node (unwrap! (map-get? compute-nodes node-id) err-not-found))
      (assignment (unwrap! (map-get? job-assignments {job-id: job-id, node-id: node-id}) err-not-found))
    )
    (asserts! (is-eq tx-sender (get requester job)) err-unauthorized)
    (asserts! (not (get work-verified assignment)) err-already-exists)
    (asserts! (<= payment-amount (get remaining-budget job)) err-invalid-amount)
    (try! (as-contract (stx-transfer? payment-amount tx-sender (get provider node))))
    (map-set job-assignments {job-id: job-id, node-id: node-id} (merge assignment {
      payment-amount: payment-amount,
      work-verified: true
    }))
    (map-set training-jobs job-id (merge job {
      remaining-budget: (- (get remaining-budget job) payment-amount)
    }))
    (map-set compute-nodes node-id (merge node {
      total-jobs-completed: (+ (get total-jobs-completed node) u1)
    }))
    (map-set node-earnings node-id
      (+ (default-to u0 (map-get? node-earnings node-id)) payment-amount))
    (ok true)
  )
)

(define-public (complete-training-job (job-id uint) (result-hash (buff 32)))
  (let
    (
      (job (unwrap! (map-get? training-jobs job-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get requester job)) err-unauthorized)
    (asserts! (not (get completed job)) err-already-exists)
    (map-set training-jobs job-id (merge job {
      completed: true,
      result-hash: (some result-hash)
    }))
    (ok true)
  )
)

(define-public (update-node-status (node-id uint) (active bool))
  (let
    (
      (node (unwrap! (map-get? compute-nodes node-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get provider node)) err-unauthorized)
    (map-set compute-nodes node-id (merge node {active: active}))
    (ok true)
  )
)

(define-read-only (get-training-job (job-id uint))
  (ok (map-get? training-jobs job-id))
)

(define-read-only (get-compute-node (node-id uint))
  (ok (map-get? compute-nodes node-id))
)

(define-read-only (get-job-assignment (job-id uint) (node-id uint))
  (ok (map-get? job-assignments {job-id: job-id, node-id: node-id}))
)

(define-read-only (get-provider-nodes (provider principal))
  (ok (map-get? provider-nodes provider))
)

(define-read-only (get-node-earnings (node-id uint))
  (ok (map-get? node-earnings node-id))
)
