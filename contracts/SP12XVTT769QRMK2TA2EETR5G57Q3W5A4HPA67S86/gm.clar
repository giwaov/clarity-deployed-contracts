;; Simple GM Contract (Clarity 4)

(define-data-var total-gms uint u0)

(define-public (say-gm)
  (begin
    (var-set total-gms (+ (var-get total-gms) u1))
    (ok (var-get total-gms))
  )
)

(define-read-only (get-total-gms)
  (ok (var-get total-gms))
)