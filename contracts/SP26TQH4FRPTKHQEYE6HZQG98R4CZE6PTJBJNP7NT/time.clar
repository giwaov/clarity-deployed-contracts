(define-data-var unlock-height uint u0)

(define-public (lock-until (height uint))
  (begin
    (var-set unlock-height height)
    (ok height)
  )
)

(define-read-only (is-unlocked)
 (>= burn-block-height (var-get unlock-height))
)
