;; define a data variable 'count' of type uint (unsigned integer) and initialize it to 0
(define-data-var count uint u0)

;; define a read-only function that returns the current value of 'count'
(define-read-only (get-count)
  (var-get count)
)

;; define a public function that increments the 'count' by 1
(define-public (increment)
  (ok (var-set count (+ (var-get count) u1)))
)
