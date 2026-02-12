;; simple-counter.clar
(define-data-var counter uint u0)

(define-read-only (get-counter)
  (var-get counter))

(define-public (increment)
  (begin
    (var-set counter (+ (var-get counter) u1))
    (ok (var-get counter))))

(define-public (reset)
  (begin
    (var-set counter u0)
    (ok (var-get counter))))

(define-public (decrement)
  (begin
    (asserts! (> (var-get counter) u0) (err u403))
    (var-set counter (- (var-get counter) u1))
    (ok (var-get counter))))
