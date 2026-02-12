(define-constant UNLOCK_TIME u1700000000) ;; unix timestamp

(define-data-var locked-amount uint u0)
(define-data-var owner principal tx-sender)

;; Lock STX into the contract
(define-public (lock (amount uint))
  (begin
    (asserts! (> amount u0) (err u100))
    (try!
      (stx-transfer?
        amount
        tx-sender
        tx-sender
      )
    )
    (var-set locked-amount (+ (var-get locked-amount) amount))
    (ok amount)
  )
)

;; Unlock STX after the time has passed
(define-public (unlock)
  (let (
        (now stacks-block-time)
        (amount (var-get locked-amount))
       )
    (asserts! (>= now UNLOCK_TIME) (err u101))
    (asserts! (> amount u0) (err u102))
    (asserts! (is-eq tx-sender (var-get owner)) (err u103))

    (begin
      (var-set locked-amount u0)
      (try!
        (stx-transfer?
          amount
          tx-sender
          tx-sender
        )
      )
      (ok amount)
    )
  )
)
