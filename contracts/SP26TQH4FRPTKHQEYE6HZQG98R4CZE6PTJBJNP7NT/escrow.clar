;; escrow.clar

(define-data-var escrow-balance uint u0)
(define-data-var depositor (optional principal) none)
(define-data-var beneficiary (optional principal) none)

;; Deposit STX into escrow
(define-public (deposit (receiver principal) (amount uint))
  (begin
    (asserts! (is-none (var-get depositor)) (err u100)) ;; escrow must be empty
    (asserts! (> amount u0) (err u101))                 ;; amount > 0

    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

    (var-set escrow-balance amount)
    (var-set depositor (some tx-sender))
    (var-set beneficiary (some receiver))

    (ok amount)
  )
)

;; Release escrowed funds to beneficiary
(define-public (release)
  (let (
    (receiver (unwrap! (var-get beneficiary) (err u102)))
    (amount (var-get escrow-balance))
  )
    (begin
      (asserts! (> amount u0) (err u103))

      (try! (stx-transfer? amount (as-contract tx-sender) receiver))

      (var-set escrow-balance u0)
      (var-set depositor none)
      (var-set beneficiary none)

      (ok true)
    )
  )
)

;; Read escrow state
(define-read-only (get-escrow)
  {
    balance: (var-get escrow-balance),
    depositor: (var-get depositor),
    beneficiary: (var-get beneficiary)
  }
)
