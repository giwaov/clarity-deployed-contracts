;; Counter Contract V5
(define-data-var counter uint u0)

(define-read-only (get-counter)
  (var-get counter))

(define-public (increment)
  (ok (var-set counter (+ (var-get counter) u1))))

(define-public (decrement)
  (ok (var-set counter (- (var-get counter) u1))))

(define-public (reset)
  (ok (var-set counter u0)))