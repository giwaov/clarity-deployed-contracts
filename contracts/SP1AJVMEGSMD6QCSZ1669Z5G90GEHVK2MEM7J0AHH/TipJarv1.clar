;; v1 - THE UNBREAKABLE TIP
(define-constant RECEIVER tx-sender)
(define-data-var total-amount uint u0)

(define-public (tip-stx (amount uint))
    (begin
        ;; 1. Transferencia simple
        (try! (stx-transfer? amount tx-sender RECEIVER))
        ;; 2. Guardar el estado
        (var-set total-amount (+ (var-get total-amount) amount))
        (ok true)
    )
)

(define-read-only (get-total)
    (var-get total-amount)
)
