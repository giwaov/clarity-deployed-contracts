
;; Nova Royalty Distributor
;; Automatically distributes royalties to creators

(define-constant ERR-INVALID-PERCENTAGE (err u100))

(define-map royalty-configs
    { asset-id: uint }
    {
        creator: principal,
        royalty-percent: uint ;; Basis points (1/10000)
    }
)

(define-public (set-royalty (asset-id uint) (percent uint))
    (begin
        (asserts! (<= percent u10000) ERR-INVALID-PERCENTAGE)
        (ok (map-set royalty-configs
            { asset-id: asset-id }
            {
                creator: tx-sender,
                royalty-percent: percent
            }
        ))
    )
)

(define-public (distribute-sale (asset-id uint) (sale-amount uint))
    (let
        (
            (config (unwrap! (map-get? royalty-configs { asset-id: asset-id }) (err u404)))
            (royalty-amount (/ (* sale-amount (get royalty-percent config)) u10000))
        )
        (if (> royalty-amount u0)
            (stx-transfer? royalty-amount tx-sender (get creator config))
            (ok true)
        )
    )
)
