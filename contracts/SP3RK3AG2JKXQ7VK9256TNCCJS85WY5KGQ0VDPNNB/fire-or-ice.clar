(define-data-var fire-count uint u0)
(define-data-var ice-count uint u0)

(define-public (vote-fire)
  (begin
    (var-set fire-count (+ (var-get fire-count) u1))
    (ok "Fire!")
  )
)

(define-public (vote-ice)
  (begin
    (var-set ice-count (+ (var-get ice-count) u1))
    (ok "Ice!")
  )
)

(define-read-only (get-balance)
  {
    fire: (var-get fire-count),
    ice: (var-get ice-count)
  }
)
