;; prediction-market.clar
;; Simple Yes/No market

(define-map bets { market: uint, user: principal, choice: bool } uint)
(define-map markets uint { total-yes: uint, total-no: uint, resolved: bool, outcome: bool })

(define-public (bet (market-id uint) (choice bool) (amount uint))
    (let
        (
            (market (default-to { total-yes: u0, total-no: u0, resolved: false, outcome: false } (map-get? markets market-id)))
        )
        (asserts! (> amount u0) (err u109))
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set bets { market: market-id, user: tx-sender, choice: choice } amount)
        (if choice
            (map-set markets market-id (merge market { total-yes: (+ (get total-yes market) amount) }))
            (map-set markets market-id (merge market { total-no: (+ (get total-no market) amount) }))
        )
        (ok true)
    )
)

(define-read-only (get-bet (market-id uint) (user principal) (choice bool))
    (ok (map-get? bets { market: market-id, user: user, choice: choice }))
)
