(define-constant ERR-UNAUTHORIZED u100)

(define-data-var governor principal tx-sender)
(define-data-var performance-fee-bps uint u1000)
(define-data-var management-fee-bps uint u50)
(define-data-var treasury principal tx-sender)
(define-data-var strategist principal tx-sender)

(define-read-only (is-governor)
  (is-eq tx-sender (var-get governor))
)

(define-public (set-governor (new-governor principal))
  (begin
    (asserts! (is-governor) (err ERR-UNAUTHORIZED))
    (var-set governor new-governor)
    (ok true)
  )
)

(define-read-only (get-fees)
  { performance-fee-bps: (var-get performance-fee-bps),
    management-fee-bps: (var-get management-fee-bps),
    treasury: (var-get treasury),
    strategist: (var-get strategist) }
)

(define-read-only (calculate-performance-fee (profit uint))
  (/ (* profit (var-get performance-fee-bps)) u10000)
)

(define-public (set-fees (performance-bps uint) (management-bps uint))
  (begin
    (asserts! (is-governor) (err ERR-UNAUTHORIZED))
    (var-set performance-fee-bps performance-bps)
    (var-set management-fee-bps management-bps)
    (ok true)
  )
)

(define-public (set-recipients (new-treasury principal) (new-strategist principal))
  (begin
    (asserts! (is-governor) (err ERR-UNAUTHORIZED))
    (var-set treasury new-treasury)
    (var-set strategist new-strategist)
    (ok true)
  )
)
