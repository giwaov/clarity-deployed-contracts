(define-data-var white-votes uint u0)
(define-data-var black-votes uint u0)

(define-public (choose-white)
  (begin
    (var-set white-votes (+ (var-get white-votes) u1))
    (ok "White chosen")
  )
)

(define-public (choose-black)
  (begin
    (var-set black-votes (+ (var-get black-votes) u1))
    (ok "Black chosen")
  )
)

(define-read-only (results)
  {
    white: (var-get white-votes),
    black: (var-get black-votes)
  }
)
