(impl-trait .strategy-trait.strategy-trait)

(define-constant CONTRACT-VERSION u1)
(define-constant STRATEGY-NAME "bitflow-lp")

(define-constant ERR-NOT-AUTHORIZED (err u310))
(define-constant ERR-INSUFFICIENT-BALANCE (err u311))
(define-constant ERR-DEPOSIT-FAILED (err u312))
(define-constant ERR-WITHDRAW-FAILED (err u313))

(define-data-var contract-owner principal tx-sender)
(define-data-var lp-position-value uint u0)
(define-data-var active bool true)
(define-data-var current-apy uint u1200)

(define-public (deposit (amount uint))
  (begin
    (var-set lp-position-value (+ (var-get lp-position-value) amount))
    (ok amount)
  )
)

(define-public (withdraw (amount uint))
  (let
    (
      (current-position (var-get lp-position-value))
    )
    (asserts! (>= current-position amount) ERR-INSUFFICIENT-BALANCE)
    (var-set lp-position-value (- current-position amount))
    (ok amount)
  )
)

(define-public (get-balance)
  (ok (var-get lp-position-value))
)

(define-public (get-apy)
  (ok (var-get current-apy))
)

(define-public (get-strategy-info)
  (ok {
    name: STRATEGY-NAME,
    risk-score: u5,
    active: (var-get active)
  })
)
