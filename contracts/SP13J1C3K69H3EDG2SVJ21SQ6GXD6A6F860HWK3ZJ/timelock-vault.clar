;; ===== Constants =====
(define-constant EARLY_PENALTY_BP u500) ;; 5% penalty (basis points)
(define-constant BASIS_POINTS u10000)

;; ===== Storage =====
(define-map vaults
  principal
  {
    balance: uint,
    unlock-time: uint
  }
)

;; ===== Helpers =====

(define-read-only (get-vault (user principal))
  (map-get? vaults user)
)

;; ===== Deposit =====
(define-public (deposit (amount uint) (unlock-time uint))
  (let ((now stacks-block-time))
    (asserts! (> amount u0) (err u100))
    (asserts! (> unlock-time now) (err u101))

    (try!
      (stx-transfer?
        amount
        tx-sender
        tx-sender
      )
    )

    (map-set vaults tx-sender {
      balance: (+ amount (default-to u0 (get balance (get-vault tx-sender)))),
      unlock-time: unlock-time
    })

    (ok amount)
  )
)

;; ===== Extend Lock =====
(define-public (extend-lock (new-unlock-time uint))
  (let ((now stacks-block-time))
    (asserts! (> new-unlock-time now) (err u102))

    (match (get-vault tx-sender)
      vault
      (begin
        (asserts! (> new-unlock-time (get unlock-time vault)) (err u103))
        (map-set vaults tx-sender {
          balance: (get balance vault),
          unlock-time: new-unlock-time
        })
        (ok new-unlock-time)
      )
      (err u404)
    )
  )
)

;; ===== Withdraw =====
(define-public (withdraw)
  (let (
        (now stacks-block-time)
        (vault-opt (get-vault tx-sender))
       )
    (match vault-opt
      vault
      (let (
            (balance (get balance vault))
            (unlock-time (get unlock-time vault))
           )
        (asserts! (> balance u0) (err u105))

        (if (>= now unlock-time)
          ;; Normal withdrawal
          (begin
            (map-delete vaults tx-sender)
            (try!
              (stx-transfer?
                balance
                tx-sender
                tx-sender
              )
            )
            (ok balance)
          )

          ;; Early withdrawal with penalty
          (let (
                (penalty (/ (* balance EARLY_PENALTY_BP) BASIS_POINTS))
                (payout (- balance penalty))
               )
            (map-delete vaults tx-sender)
            (try!
              (stx-transfer?
                payout
                tx-sender
                tx-sender
              )
            )
            (ok payout)
          )
        )
      )
      (err u404)
    )
  )
)
