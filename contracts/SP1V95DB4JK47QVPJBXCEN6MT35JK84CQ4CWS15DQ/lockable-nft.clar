(define-non-fungible-token lockable-nft uint)

(define-data-var last-token-id uint u0)
(define-data-var default-locked bool true)

(define-map locked-tokens uint bool)
(define-map token-owner uint principal)
(define-map approvals { token-id: uint, operator: principal } bool)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-token-not-found (err u102))
(define-constant err-token-locked (err u103))
(define-constant err-already-locked (err u104))
(define-constant err-already-unlocked (err u105))

(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? lockable-nft token-id))
)

(define-read-only (get-default-locked)
    (ok (var-get default-locked))
)

(define-read-only (is-locked (token-id uint))
    (ok (default-to (var-get default-locked) (map-get? locked-tokens token-id)))
)

(define-public (set-default-locked (locked bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (var-set default-locked locked))
    )
)

(define-public (mint (recipient principal))
    (let
        (
            (token-id (+ (var-get last-token-id) u1))
        )
        (try! (nft-mint? lockable-nft token-id recipient))
        (map-set token-owner token-id recipient)
        (var-set last-token-id token-id)
        (ok token-id)
    )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (let
        (
            (token-locked (unwrap! (is-locked token-id) err-token-not-found))
        )
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (asserts! (not token-locked) err-token-locked)
        (try! (nft-transfer? lockable-nft token-id sender recipient))
        (map-set token-owner token-id recipient)
        (ok true)
    )
)

(define-public (lock (token-id uint))
    (let
        (
            (current-owner (unwrap! (nft-get-owner? lockable-nft token-id) err-token-not-found))
            (token-locked (unwrap! (is-locked token-id) err-token-not-found))
        )
        (asserts! (is-eq tx-sender current-owner) err-not-token-owner)
        (asserts! (not token-locked) err-already-locked)
        (map-set locked-tokens token-id true)
        (ok true)
    )
)

(define-public (unlock (token-id uint))
    (let
        (
            (current-owner (unwrap! (nft-get-owner? lockable-nft token-id) err-token-not-found))
            (token-locked (unwrap! (is-locked token-id) err-token-not-found))
        )
        (asserts! (is-eq tx-sender current-owner) err-not-token-owner)
        (asserts! token-locked err-already-unlocked)
        (map-set locked-tokens token-id false)
        (ok true)
    )
)
