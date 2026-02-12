

(define-data-var counter uint u0)

(define-public (increment)
  (let ((new-value (+ (var-get counter) u1)))
    (begin
      (var-set counter new-value)
      (ok new-value)
    )
  )
)

(define-read-only (get-counter)
  (var-get counter)
)
