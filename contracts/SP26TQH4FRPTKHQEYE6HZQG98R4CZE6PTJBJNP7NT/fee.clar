(define-data-var fees uint u0)

(define-public (collect (amount uint))
  (begin
    (var-set fees (+ (var-get fees) amount))
    (ok amount)
  )
)
