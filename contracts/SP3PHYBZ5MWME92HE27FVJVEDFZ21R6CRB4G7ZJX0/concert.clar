;; Contract: Concert Details
;; Description: Manages event capacity.

(define-constant max-seats u100)
(define-data-var sold-seats uint u0)

(define-public (register-seat)
    (let
        (
            (current (var-get sold-seats))
        )
        (asserts! (< current max-seats) (err u500)) ;; Full capacity
        (var-set sold-seats (+ current u1))
        (ok true)
    )
)

(define-read-only (seats-left)
    (ok (- max-seats (var-get sold-seats)))
)