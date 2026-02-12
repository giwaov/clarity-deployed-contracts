
;; counter
;; <add a description here>

;; constants
;;

;; data maps and vars
;;
(define-data-var count uint u0)

;; private functions
;;

;; public functions
;;
(define-read-only (get-count)
  (ok (var-get count))
)

(define-public (increment)
  (begin
    (var-set count (+ (var-get count) u1))
    (print {event: "increment", count: (var-get count)})
    (ok (var-get count))
  )
)

(define-public (decrement)
  (begin
    (var-set count (- (var-get count) u1))
    (print {event: "decrement", count: (var-get count)})
    (ok (var-get count))
  )
)
