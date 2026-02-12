;; recurring-payment.clar
;; authorized pulls

(define-map limits principal uint)

(define-public (authorize (amount uint))
    (ok (map-set limits tx-sender amount))
)

(define-public (pull-payment (from principal) (amount uint))
    (let
        (
            (limit (default-to u0 (map-get? limits from)))
        )
        (asserts! (<= amount limit) (err u100))
        (try! (stx-transfer? amount from tx-sender))
        (map-set limits from (- limit amount))
        (ok true)
    )
)
