;; v7-ultra-light
(define-non-fungible-token VIP-CARD uint)

(define-data-var last-id uint u0)
(define-data-var owner principal tx-sender)

(define-map donations principal uint)
(define-map has-nft principal bool)

(define-public (donate (amount uint))
    (let ((prev (default-to u0 (map-get? donations tx-sender))))
        (try! (stx-transfer? amount tx-sender (var-get owner)))
        (map-set donations tx-sender (+ prev amount))
        (ok true)
    )
)

(define-public (claim-membership)
    (let (
        (total (default-to u0 (map-get? donations tx-sender)))
        (new-id (+ (var-get last-id) u1))
    )
        (asserts! (>= total u10000000) (err u403))
        (asserts! (is-none (map-get? has-nft tx-sender)) (err u406))
        (try! (nft-mint? VIP-CARD new-id tx-sender))
        (var-set last-id new-id)
        (map-set has-nft tx-sender true)
        (ok new-id)
    )
)

(define-read-only (get-info (user principal))
    {
        amt: (default-to u0 (map-get? donations user)),
        nft: (default-to false (map-get? has-nft user))
    }
)
