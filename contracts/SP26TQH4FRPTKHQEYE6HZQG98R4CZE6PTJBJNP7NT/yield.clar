(define-data-var yield uint u0)

(define-public (add-yield (amount uint))
  (begin
    (var-set yield (+ (var-get yield) amount))
    (ok amount)
  )
)
