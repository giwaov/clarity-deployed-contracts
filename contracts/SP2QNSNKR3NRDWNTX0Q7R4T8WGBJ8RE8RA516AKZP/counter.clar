;; Counter Smart Contract
;; A simple counter that can be incremented and read

(define-data-var counter int 0)

;; Increment the counter by 1
(define-public (increment)
  (begin
    (var-set counter (+ (var-get counter) 1))
    (ok (var-get counter))
  )
)

;; Decrement the counter by 1
(define-public (decrement)
  (begin
    (var-set counter (- (var-get counter) 1))
    (ok (var-get counter))
  )
)

;; Get the current counter value
(define-read-only (get-counter)
  (ok (var-get counter))
)

;; Reset the counter to 0
(define-public (reset)
  (begin
    (var-set counter 0)
    (ok (var-get counter))
  )
)

