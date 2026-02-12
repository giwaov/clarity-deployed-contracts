;; simple-timelock.clar

(define-constant ERR-TOO-EARLY u102)

(define-data-var unlock-height uint u0)

(define-public (set-unlock-height (h uint))
  (begin (var-set unlock-height h) (ok true)))

(define-read-only (can-unlock)
  (>= burn-block-height (var-get unlock-height)))

(define-public (assert-unlocked)
  (if (>= burn-block-height (var-get unlock-height))
    (ok true)
    (err ERR-TOO-EARLY)))
