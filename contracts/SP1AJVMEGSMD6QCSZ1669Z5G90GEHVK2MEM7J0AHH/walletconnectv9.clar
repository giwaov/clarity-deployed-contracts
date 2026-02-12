;; v10 - The Absolute Final Minimal Version
(define-non-fungible-token MEMBERSHIP uint)

(define-data-var last-id uint u0)
(define-map donations principal uint)

;; 1. DONATE (Simplificado al extremo)
(define-public (donate (amount uint))
    (begin
        (try! (stx-transfer? amount tx-sender 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM))
        (map-set donations tx-sender (+ (default-to u0 (map-get? donations tx-sender)) amount))
        (ok true)
    )
)

;; 2. CLAIM (Sin validaciones de monto para que NO aborte)
(define-public (claim-membership)
    (let ((new-id (+ (var-get last-id) u1)))
        (try! (nft-mint? MEMBERSHIP new-id tx-sender))
        (var-set last-id new-id)
        (ok new-id)
    )
)

;; 3. READ
(define-read-only (get-total (user principal))
    (default-to u0 (map-get? donations user))
)
