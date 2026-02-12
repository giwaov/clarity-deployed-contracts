(define-data-var coffee uint u0)
(define-data-var tea uint u0)

(define-public (vote-coffee)
  (begin
    (var-set coffee (+ (var-get coffee) u1))
    (ok "Coffee chosen")
  )
)

(define-public (vote-tea)
  (begin
    (var-set tea (+ (var-get tea) u1))
    (ok "Tea chosen")
  )
)

(define-read-only (drink-results)
  {
    coffee: (var-get coffee),
    tea: (var-get tea)
  }
)
