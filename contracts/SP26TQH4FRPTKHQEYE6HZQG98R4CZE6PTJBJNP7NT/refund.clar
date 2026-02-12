(define-data-var refundable uint u0)

(define-public (add (amount uint))
  (begin
    (var-set refundable (+ (var-get refundable) amount))
    (ok amount)
  )
)
