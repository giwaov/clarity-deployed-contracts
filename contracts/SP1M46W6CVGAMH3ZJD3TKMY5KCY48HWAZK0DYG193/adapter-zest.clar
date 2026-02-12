(impl-trait .strategy-trait.strategy-trait)

(define-constant CONTRACT-VERSION u1)
(define-constant STRATEGY-NAME "zest-lending")

(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-INSUFFICIENT-BALANCE (err u301))
(define-constant ERR-DEPOSIT-FAILED (err u302))
(define-constant ERR-WITHDRAW-FAILED (err u303))

(define-data-var contract-owner principal tx-sender)
(define-data-var zest-balance uint u0)
(define-data-var active bool true)
(define-data-var current-apy uint u800)

(define-public (deposit (amount uint))
  (begin
    (var-set zest-balance (+ (var-get zest-balance) amount))
    (ok amount)
  )
)

(define-public (withdraw (amount uint))
  (let
    (
      (current-balance (var-get zest-balance))
    )
    (asserts! (>= current-balance amount) ERR-INSUFFICIENT-BALANCE)
    (var-set zest-balance (- current-balance amount))
    (ok amount)
  )
)

(define-public (get-balance)
  (ok (var-get zest-balance))
)

(define-public (get-apy)
  (ok (var-get current-apy))
)

(define-public (get-strategy-info)
  (ok {
    name: STRATEGY-NAME,
    risk-score: u3,
    active: (var-get active)
  })
)
