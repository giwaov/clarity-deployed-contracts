(define-trait strategy-trait
  (
    (deposit (uint) (response uint uint))
    (withdraw (uint) (response uint uint))
    (get-balance () (response uint uint))
    (get-apy () (response uint uint))
    (get-strategy-info () (response {name: (string-ascii 32), risk-score: uint, active: bool} uint))
  )
)
