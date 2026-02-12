(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-insufficient-stake (err u105))
(define-constant err-already-staked (err u106))
(define-constant err-model-inactive (err u107))

(define-data-var model-nonce uint u0)
(define-data-var task-nonce uint u0)

(define-map models
  uint
  {
    provider: principal,
    model-hash: (buff 32),
    compute-power: uint,
    price-per-inference: uint,
    stake-amount: uint,
    active: bool,
    total-inferences: uint,
    reputation-score: uint
  }
)

(define-map inference-tasks
  uint
  {
    requester: principal,
    model-id: uint,
    input-hash: (buff 32),
    output-hash: (optional (buff 32)),
    payment-amount: uint,
    completed: bool,
    verified: bool
  }
)

(define-map provider-models principal (list 100 uint))
(define-map model-earnings uint uint)

(define-public (register-model (model-hash (buff 32)) (compute-power uint) (price-per-inference uint) (stake-amount uint))
  (let
    (
      (model-id (+ (var-get model-nonce) u1))
    )
    (asserts! (> stake-amount u0) err-invalid-amount)
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    (map-set models model-id
      {
        provider: tx-sender,
        model-hash: model-hash,
        compute-power: compute-power,
        price-per-inference: price-per-inference,
        stake-amount: stake-amount,
        active: true,
        total-inferences: u0,
        reputation-score: u100
      }
    )
    (map-set model-earnings model-id u0)
    (map-set provider-models tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? provider-models tx-sender)) model-id) u100)))
    (var-set model-nonce model-id)
    (ok model-id)
  )
)

(define-public (request-inference (model-id uint) (input-hash (buff 32)))
  (let
    (
      (model (unwrap! (map-get? models model-id) err-not-found))
      (task-id (+ (var-get task-nonce) u1))
      (payment (get price-per-inference model))
    )
    (asserts! (get active model) err-model-inactive)
    (try! (stx-transfer? payment tx-sender (as-contract tx-sender)))
    (map-set inference-tasks task-id
      {
        requester: tx-sender,
        model-id: model-id,
        input-hash: input-hash,
        output-hash: none,
        payment-amount: payment,
        completed: false,
        verified: false
      }
    )
    (var-set task-nonce task-id)
    (ok task-id)
  )
)

(define-public (submit-inference (task-id uint) (output-hash (buff 32)))
  (let
    (
      (task (unwrap! (map-get? inference-tasks task-id) err-not-found))
      (model (unwrap! (map-get? models (get model-id task)) err-not-found))
    )
    (asserts! (is-eq tx-sender (get provider model)) err-unauthorized)
    (asserts! (not (get completed task)) err-already-exists)
    (map-set inference-tasks task-id (merge task {
      output-hash: (some output-hash),
      completed: true
    }))
    (ok true)
  )
)

(define-public (verify-and-pay (task-id uint))
  (let
    (
      (task (unwrap! (map-get? inference-tasks task-id) err-not-found))
      (model (unwrap! (map-get? models (get model-id task)) err-not-found))
    )
    (asserts! (is-eq tx-sender (get requester task)) err-unauthorized)
    (asserts! (get completed task) err-not-found)
    (asserts! (not (get verified task)) err-already-exists)
    (try! (as-contract (stx-transfer? (get payment-amount task) tx-sender (get provider model))))
    (map-set inference-tasks task-id (merge task {verified: true}))
    (map-set models (get model-id task) (merge model {
      total-inferences: (+ (get total-inferences model) u1)
    }))
    (map-set model-earnings (get model-id task)
      (+ (default-to u0 (map-get? model-earnings (get model-id task))) (get payment-amount task)))
    (ok true)
  )
)

(define-public (update-model-status (model-id uint) (active bool))
  (let
    (
      (model (unwrap! (map-get? models model-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get provider model)) err-unauthorized)
    (map-set models model-id (merge model {active: active}))
    (ok true)
  )
)

(define-public (withdraw-stake (model-id uint))
  (let
    (
      (model (unwrap! (map-get? models model-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get provider model)) err-unauthorized)
    (asserts! (not (get active model)) err-model-inactive)
    (try! (as-contract (stx-transfer? (get stake-amount model) tx-sender (get provider model))))
    (map-set models model-id (merge model {stake-amount: u0}))
    (ok true)
  )
)

(define-read-only (get-model (model-id uint))
  (ok (map-get? models model-id))
)

(define-read-only (get-task (task-id uint))
  (ok (map-get? inference-tasks task-id))
)

(define-read-only (get-provider-models (provider principal))
  (ok (map-get? provider-models provider))
)

(define-read-only (get-model-earnings (model-id uint))
  (ok (map-get? model-earnings model-id))
)
