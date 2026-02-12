;; v8 - Ultra Stable Edition
(define-non-fungible-token VIP-CARD uint)

(define-data-var last-id uint u0)
(define-data-var owner principal tx-sender)

(define-map donations principal uint)

;; 1. DONATE
(define-public (donate (amount uint))
    (begin
        (try! (stx-transfer? amount tx-sender (var-get owner)))
        (map-set donations tx-sender (+ (default-to u0 (map-get? donations tx-sender)) amount))
        (ok true)
    )
)

;; 2. CLAIM NFT
(define-public (claim-membership)
    (let 
        (
            (new-id (+ (var-get last-id) u1))
            (total (default-to u0 (map-get? donations tx-sender)))
        )
        (asserts! (>= total u10000000) (err u403))
        (try! (nft-mint? VIP-CARD new-id tx-sender))
        (var-set last-id new-id)
        (ok new-id)
    )
)

;; 3. GET DATA
(define-read-only (get-user-data (user principal))
    (ok (default-to u0 (map-get? donations user)))
)
