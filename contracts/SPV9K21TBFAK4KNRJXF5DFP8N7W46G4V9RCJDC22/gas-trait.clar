(define-trait gas-trait
  (
    (pay-gas () (response bool uint))
    (get-gas-amount () (response uint uint))
  )
)