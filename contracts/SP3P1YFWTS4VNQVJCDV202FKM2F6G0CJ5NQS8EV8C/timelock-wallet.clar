;; timelock-wallet.clar
;; Allows users to lock STX until a specific timestamp

(define-map time-locked-balances principal { amount: uint, unlock-time: uint })

(define-public (lock (amount uint) (unlock-time uint))
    (let
        (
            (current-balance (default-to u0 (get amount (map-get? time-locked-balances tx-sender))))
        )
        (asserts! (> unlock-time stacks-block-height) (err u101)) ;; ERR_INVALID_TIME
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set time-locked-balances tx-sender { amount: (+ current-balance amount), unlock-time: unlock-time })
        (ok true)
    )
)

(define-public (withdraw)
    (let
        (
            (entry (unwrap! (map-get? time-locked-balances tx-sender) (err u102))) ;; ERR_NO_BALANCE
            (amount (get amount entry))
            (unlock-time (get unlock-time entry))
        )
        (asserts! (>= stacks-block-height unlock-time) (err u103)) ;; ERR_STILL_LOCKED
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        (map-delete time-locked-balances tx-sender)
        (ok amount)
    )
)
