(define-map stacking-info principal {
    amount: uint,
    cycle: uint
})

(define-public (log-stacking (amount uint) (cycle uint))
    (begin
        (map-set stacking-info tx-sender {amount: amount, cycle: cycle})
        (ok true)
    )
)

(define-read-only (get-stacking-info (user principal))
    (ok (map-get? stacking-info user))
)
