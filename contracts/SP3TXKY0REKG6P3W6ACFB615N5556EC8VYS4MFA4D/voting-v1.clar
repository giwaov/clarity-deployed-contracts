;; simple-voting.clar
;; Updated: Allows multiple votes from the same address

(define-data-var yes uint u0)
(define-data-var no uint u0)

(define-public (vote-yes)
  (begin
    (var-set yes (+ (var-get yes) u1))
    (ok true)))

(define-public (vote-no)
  (begin
    (var-set no (+ (var-get no) u1))
    (ok true)))

(define-read-only (get-results)
  (ok {yes: (var-get yes), no: (var-get no)}))
