;; Yield Optimizer
;; Automatically optimizes yield across protocols

(define-constant contract-owner tx-sender)
(define-data-var current-strategy uint u1)
(define-data-var total-deposits uint u0)

(define-map user-deposits principal uint)

(define-read-only (get-optimal-yield)
  (var-get current-strategy)
)

(define-public (deposit-for-optimization (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set user-deposits tx-sender (+ (default-to u0 (map-get? user-deposits tx-sender)) amount))
    (var-set total-deposits (+ (var-get total-deposits) amount))
    (ok amount)
  )
)

(define-public (rebalance-strategy (new-strategy uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err u100))
    (var-set current-strategy new-strategy)
    (ok true)
  )
)
