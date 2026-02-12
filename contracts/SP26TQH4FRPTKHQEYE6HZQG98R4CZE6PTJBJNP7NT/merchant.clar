(define-data-var locked uint u0)

(define-public (lock (amount uint))
  (begin
    (var-set locked amount)
    (ok amount)
  )
)
