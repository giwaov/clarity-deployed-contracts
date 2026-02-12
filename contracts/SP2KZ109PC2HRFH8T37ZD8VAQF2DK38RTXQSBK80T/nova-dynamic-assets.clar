
;; nova-dynamic-assets.clar
;; NFT collection where metadata can evolve.
;; CLARITY VERSION: 2

(impl-trait .nova-trait-non-fungible.nova-trait-non-fungible)

(define-non-fungible-token dynamic-gem uint)

(define-data-var last-id uint u0)

(define-map token-levels uint uint) ;; Token ID -> Level

(define-constant ERR-NOT-OWNER (err u100))

(define-public (mint (recipient principal))
    (let (
        (id (+ (var-get last-id) u1))
    )
    (try! (nft-mint? dynamic-gem id recipient))
    (map-set token-levels id u1)
    (var-set last-id id)
    (ok id))
)

(define-public (level-up (token-id uint))
    (let (
        (owner (unwrap! (nft-get-owner? dynamic-gem token-id) (err u101)))
        (current-level (default-to u1 (map-get? token-levels token-id)))
    )
    (asserts! (is-eq tx-sender owner) ERR-NOT-OWNER)
    ;; Add cost logic if needed
    (map-set token-levels token-id (+ current-level u1))
    (ok true))
)

;; SIP-009 Interface

(define-read-only (get-last-token-id)
    (ok (var-get last-id))
)

(define-read-only (get-token-uri (token-id uint))
    (match (map-get? token-levels token-id)
        level (ok (some (buff-to-string-ascii (unwrap-panic (to-consensus-buff? {id: token-id, level: level}))))) ;; Mock URI based on state
        (ok none)
    )
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? dynamic-gem token-id))
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-NOT-OWNER)
        (nft-transfer? dynamic-gem token-id sender recipient)
    )
)

;; Helper to convert buff to string-ascii logic typically required, simplified here approx.
(define-private (buff-to-string-ascii (b (buff 256)))
    "http://mock-uri" ;; Placeholder for complex string conversion
)
