
;; nova-math-utils.clar
;; Math helpers
;; CLARITY VERSION: 2

(define-read-only (safe-mul (a uint) (b uint))
    (ok (* a b))
)

(define-read-only (safe-div (a uint) (b uint))
    (if (is-eq b u0)
        (err u100)
        (ok (/ a b))
    )
)
