(define-constant CONTRACT-VERSION u1)

(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-STRATEGY-NOT-FOUND (err u201))
(define-constant ERR-STRATEGY-INACTIVE (err u202))
(define-constant ERR-INVALID-ALLOCATION (err u203))
(define-constant ERR-INSUFFICIENT-LIQUIDITY (err u204))
(define-constant ERR-REBALANCE-THRESHOLD-NOT-MET (err u205))

(define-data-var contract-owner principal tx-sender)

(define-map strategies
  {strategy-id: (string-ascii 32)}
  {
    adapter-contract: principal,
    active: bool,
    risk-score: uint,
    current-allocation: uint,
    target-percentage: uint
  }
)

(define-data-var rebalance-threshold uint u500)
(define-data-var last-rebalance-block uint u0)
(define-data-var min-rebalance-interval uint u144)
(define-data-var active-strategies (list 10 (string-ascii 32)) (list))

(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-public (register-strategy
  (strategy-id (string-ascii 32))
  (adapter principal)
  (risk-score uint)
  (target-pct uint)
)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (<= target-pct u10000) ERR-INVALID-ALLOCATION)
    (map-set strategies
      {strategy-id: strategy-id}
      {
        adapter-contract: adapter,
        active: true,
        risk-score: risk-score,
        current-allocation: u0,
        target-percentage: target-pct
      }
    )
    (var-set active-strategies
      (unwrap-panic (as-max-len?
        (append (var-get active-strategies) strategy-id)
        u10
      ))
    )
    (ok strategy-id)
  )
)

(define-public (deactivate-strategy (strategy-id (string-ascii 32)))
  (let
    (
      (strategy (unwrap! (map-get? strategies {strategy-id: strategy-id}) ERR-STRATEGY-NOT-FOUND))
    )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (map-set strategies
      {strategy-id: strategy-id}
      (merge strategy {active: false})
    )
    (ok true)
  )
)

(define-read-only (get-strategy-info (strategy-id (string-ascii 32)))
  (ok (map-get? strategies {strategy-id: strategy-id}))
)

(define-read-only (get-active-strategies)
  (ok (var-get active-strategies))
)

(define-read-only (get-total-allocation)
  (ok u0)
)

(define-public (update-target-allocation
  (strategy-id (string-ascii 32))
  (new-target uint)
)
  (let
    (
      (strategy (unwrap! (map-get? strategies {strategy-id: strategy-id}) ERR-STRATEGY-NOT-FOUND))
    )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-target u10000) ERR-INVALID-ALLOCATION)
    (map-set strategies
      {strategy-id: strategy-id}
      (merge strategy {target-percentage: new-target})
    )
    (ok new-target)
  )
)

(define-public (allocate-capital (amount uint))
  (begin
    (ok amount)
  )
)

(define-public (free-capital (amount uint))
  (begin
    (ok amount)
  )
)

(define-public (rebalance)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts!
      (>= (- block-height (var-get last-rebalance-block)) (var-get min-rebalance-interval))
      ERR-REBALANCE-THRESHOLD-NOT-MET
    )
    (var-set last-rebalance-block block-height)
    (ok true)
  )
)

(define-public (update-rebalance-config (threshold uint) (interval uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set rebalance-threshold threshold)
    (var-set min-rebalance-interval interval)
    (ok true)
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set contract-owner new-owner)
    (ok new-owner)
  )
)
