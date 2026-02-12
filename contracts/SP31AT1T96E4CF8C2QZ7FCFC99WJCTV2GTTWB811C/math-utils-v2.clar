(define-read-only (safe-add (a uint) (b uint))
    (ok (+ a b))
)

(define-read-only (safe-multiply (a uint) (b uint))
    (ok (* a b))
)
