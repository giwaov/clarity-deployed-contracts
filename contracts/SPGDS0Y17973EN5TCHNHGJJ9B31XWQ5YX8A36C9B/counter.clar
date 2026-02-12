;; Counter smart contract for Stacks blockchain
;; Implements a simple counter with increment, decrement, and read functions

;; Define the counter variable, starting at 0
(define-data-var counter uint u0)

;; Read-only function to get the current counter value
(define-read-only (get-counter)
  (var-get counter)
)

;; Public function to increment the counter by 1
(define-public (increment)
  (begin
    (print "Incrementing counter")
    (ok (var-set counter (+ (var-get counter) u1)))
  )
)

;; Public function to decrement the counter by 1, fails if counter would go below 0
(define-public (decrement)
  (let ((current-count (var-get counter)))
    (if (> current-count u0)
      (begin
        (print "Decrementing counter")
        (ok (var-set counter (- current-count u1)))
      )
      (err u1) ;; Error code 1 for underflow
    )
  )
)