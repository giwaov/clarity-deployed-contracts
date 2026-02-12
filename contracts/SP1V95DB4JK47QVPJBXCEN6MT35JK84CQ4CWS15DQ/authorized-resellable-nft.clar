(define-non-fungible-token ticket uint)

(define-map token-status
    uint
    (string-ascii 10)
)

(define-map token-owner uint principal)

(define-map authorized-resellers
    principal
    bool
)

(define-map resale-history
    { token-id: uint, index: uint }
    { from: principal, to: principal, timestamp: uint, price: uint }
)

(define-map resale-count uint uint)

(define-data-var last-token-id uint u0)

(define-constant contract-owner tx-sender)
(define-constant status-sold "Sold")
(define-constant status-resell "Resell")
(define-constant status-void "Void")
(define-constant status-redeemed "Redeemed")

(define-constant err-not-owner (err u100))
(define-constant err-not-found (err u101))
(define-constant err-invalid-status (err u102))
(define-constant err-not-reseller (err u103))
(define-constant err-already-redeemed (err u104))

(define-read-only (get-token-status (token-id uint))
    (ok (map-get? token-status token-id))
)

(define-read-only (get-owner (token-id uint))
    (ok (map-get? token-owner token-id))
)

(define-read-only (is-authorized-reseller (reseller principal))
    (ok (default-to false (map-get? authorized-resellers reseller)))
)

(define-read-only (get-resale-history (token-id uint) (index uint))
    (ok (map-get? resale-history { token-id: token-id, index: index }))
)

(define-public (mint (recipient principal))
    (let
        (
            (token-id (+ (var-get last-token-id) u1))
        )
        (try! (nft-mint? ticket token-id recipient))
        (map-set token-owner token-id recipient)
        (map-set token-status token-id status-sold)
        (var-set last-token-id token-id)
        (ok token-id)
    )
)

(define-public (authorize-reseller (reseller principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-owner)
        (map-set authorized-resellers reseller true)
        (ok true)
    )
)

(define-public (revoke-reseller (reseller principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-owner)
        (map-delete authorized-resellers reseller)
        (ok true)
    )
)

(define-public (resell (token-id uint) (new-owner principal) (price uint))
    (let
        (
            (owner (unwrap! (map-get? token-owner token-id) err-not-found))
            (status (unwrap! (map-get? token-status token-id) err-not-found))
            (is-authorized (default-to false (map-get? authorized-resellers tx-sender)))
            (count (default-to u0 (map-get? resale-count token-id)))
        )
        (asserts! is-authorized err-not-reseller)
        (asserts! (not (is-eq status status-redeemed)) err-already-redeemed)
        (try! (nft-transfer? ticket token-id owner new-owner))
        (map-set token-owner token-id new-owner)
        (map-set token-status token-id status-resell)
        (map-set resale-history { token-id: token-id, index: count }
            { from: owner, to: new-owner, timestamp: stacks-block-time, price: price }
        )
        (map-set resale-count token-id (+ count u1))
        (ok true)
    )
)

(define-public (change-status (token-id uint) (new-status (string-ascii 10)))
    (let
        (
            (owner (unwrap! (map-get? token-owner token-id) err-not-found))
        )
        (asserts! (is-eq tx-sender owner) err-not-owner)
        (map-set token-status token-id new-status)
        (ok true)
    )
)

(define-public (redeem (token-id uint))
    (let
        (
            (owner (unwrap! (map-get? token-owner token-id) err-not-found))
            (status (unwrap! (map-get? token-status token-id) err-not-found))
        )
        (asserts! (is-eq tx-sender owner) err-not-owner)
        (asserts! (not (is-eq status status-redeemed)) err-already-redeemed)
        (map-set token-status token-id status-redeemed)
        (ok true)
    )
)
