(define-data-var sun-votes uint u0)
(define-data-var moon-votes uint u0)

(define-public (vote-sun)
  (begin
    (var-set sun-votes (+ (var-get sun-votes) u1))
    (ok "Sun selected")
  )
)

(define-public (vote-moon)
  (begin
    (var-set moon-votes (+ (var-get moon-votes) u1))
    (ok "Moon selected")
  )
)

(define-read-only (solar-results)
  {
    sun: (var-get sun-votes),
    moon: (var-get moon-votes)
  }
)
