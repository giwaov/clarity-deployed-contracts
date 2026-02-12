;; Strategy Manager Contract

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))

(define-data-var active-strategy uint u0)

(define-public (execute-strategy (strategy-id uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set active-strategy strategy-id)
    (ok true)
  )
)

(define-public (rebalance)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok true)
  )
)
