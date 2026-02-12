(impl-trait .strategy-trait.strategy-trait)

(define-constant CONTRACT-VERSION u1)
(define-constant STRATEGY-NAME "pox-stacking")

(define-constant ERR-NOT-AUTHORIZED (err u320))
(define-constant ERR-INSUFFICIENT-BALANCE (err u321))
(define-constant ERR-STACKING-FAILED (err u322))
(define-constant ERR-UNSTACKING-FAILED (err u323))

(define-data-var contract-owner principal tx-sender)
(define-data-var stacked-amount uint u0)
(define-data-var active bool true)
(define-data-var current-apy uint u600)

(define-public (deposit (amount uint))
  (begin
    (var-set stacked-amount (+ (var-get stacked-amount) amount))
    (ok amount)
  )
)

(define-public (withdraw (amount uint))
  (let
    (
      (current-stacked (var-get stacked-amount))
    )
    (asserts! (>= current-stacked amount) ERR-INSUFFICIENT-BALANCE)
    (var-set stacked-amount (- current-stacked amount))
    (ok amount)
  )
)

(define-public (get-balance)
  (ok (var-get stacked-amount))
)

(define-public (get-apy)
  (ok (var-get current-apy))
)

(define-public (get-strategy-info)
  (ok {
    name: STRATEGY-NAME,
    risk-score: u2,
    active: (var-get active)
  })
)
