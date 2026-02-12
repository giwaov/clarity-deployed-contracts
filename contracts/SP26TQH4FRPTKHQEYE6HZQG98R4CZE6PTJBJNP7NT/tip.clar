(define-data-var total-tips uint u0)

(define-public (tip (amount uint))
  (begin
    (var-set total-tips (+ (var-get total-tips) amount))
    (ok amount)
  )
)
