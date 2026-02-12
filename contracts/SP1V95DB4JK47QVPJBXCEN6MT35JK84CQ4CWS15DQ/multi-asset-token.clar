(define-non-fungible-token multi-asset-token uint)

(define-map token-assets
    { token-id: uint, asset-id: uint }
    { metadata-uri: (string-ascii 256), priority: uint }
)

(define-map pending-assets
    { token-id: uint, asset-id: uint }
    { metadata-uri: (string-ascii 256), replaces-id: uint }
)

(define-map asset-count { token-id: uint } { active: uint, pending: uint })
(define-map asset-approvals { token-id: uint, operator: principal } bool)
(define-map asset-approvals-for-all { owner: principal, operator: principal } bool)
(define-map token-uris uint (string-ascii 256))

(define-data-var token-id-nonce uint u0)
(define-data-var asset-id-nonce uint u0)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-invalid-token (err u102))
(define-constant err-not-approved (err u103))
(define-constant err-asset-not-found (err u104))
(define-constant err-invalid-index (err u105))

(define-read-only (get-last-token-id)
    (ok (var-get token-id-nonce))
)

(define-read-only (get-token-uri (token-id uint))
    (ok (map-get? token-uris token-id))
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? multi-asset-token token-id))
)

(define-read-only (get-active-assets (token-id uint))
    (let
        (
            (counts (default-to { active: u0, pending: u0 } (map-get? asset-count { token-id: token-id })))
        )
        (ok (list))
    )
)

(define-read-only (get-pending-assets (token-id uint))
    (let
        (
            (counts (default-to { active: u0, pending: u0 } (map-get? asset-count { token-id: token-id })))
        )
        (ok (list))
    )
)

(define-read-only (get-active-asset-priorities (token-id uint))
    (ok (list))
)

(define-read-only (get-asset-replacements (token-id uint) (new-asset-id uint))
    (let
        (
            (pending (map-get? pending-assets { token-id: token-id, asset-id: new-asset-id }))
        )
        (ok (if (is-some pending) (get replaces-id (unwrap-panic pending)) u0))
    )
)

(define-read-only (get-asset-metadata (token-id uint) (asset-id uint))
    (let
        (
            (asset (map-get? token-assets { token-id: token-id, asset-id: asset-id }))
        )
        (ok (if (is-some asset) (get metadata-uri (unwrap-panic asset)) ""))
    )
)

(define-read-only (get-approved-for-assets (token-id uint))
    (ok none)
)

(define-read-only (is-approved-for-all-for-assets (owner principal) (operator principal))
    (ok (default-to false (map-get? asset-approvals-for-all { owner: owner, operator: operator })))
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (map-delete asset-approvals { token-id: token-id, operator: sender })
        (nft-transfer? multi-asset-token token-id sender recipient)
    )
)

(define-public (mint (recipient principal))
    (let
        (
            (new-token-id (+ (var-get token-id-nonce) u1))
        )
        (try! (nft-mint? multi-asset-token new-token-id recipient))
        (map-set asset-count { token-id: new-token-id } { active: u0, pending: u0 })
        (var-set token-id-nonce new-token-id)
        (ok new-token-id)
    )
)

(define-public (add-asset-to-token (token-id uint) (metadata-uri (string-ascii 256)) (replaces-id uint))
    (let
        (
            (new-asset-id (+ (var-get asset-id-nonce) u1))
            (counts (default-to { active: u0, pending: u0 } (map-get? asset-count { token-id: token-id })))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set pending-assets { token-id: token-id, asset-id: new-asset-id } { metadata-uri: metadata-uri, replaces-id: replaces-id })
        (map-set asset-count { token-id: token-id } (merge counts { pending: (+ (get pending counts) u1) }))
        (var-set asset-id-nonce new-asset-id)
        (print { type: "asset-added-to-token", token-id: token-id, asset-id: new-asset-id, replaces-id: replaces-id })
        (ok new-asset-id)
    )
)

(define-public (accept-asset (token-id uint) (index uint) (asset-id uint))
    (let
        (
            (token-owner (unwrap! (nft-get-owner? multi-asset-token token-id) err-invalid-token))
            (pending (unwrap! (map-get? pending-assets { token-id: token-id, asset-id: asset-id }) err-asset-not-found))
            (counts (default-to { active: u0, pending: u0 } (map-get? asset-count { token-id: token-id })))
            (replaces-id (get replaces-id pending))
        )
        (asserts! (or (is-eq tx-sender token-owner) (is-approved-for-assets token-id tx-sender)) err-not-approved)
        (map-delete pending-assets { token-id: token-id, asset-id: asset-id })
        (map-set token-assets { token-id: token-id, asset-id: asset-id } { metadata-uri: (get metadata-uri pending), priority: u1 })
        (if (> replaces-id u0)
            (map-delete token-assets { token-id: token-id, asset-id: replaces-id })
            true
        )
        (map-set asset-count { token-id: token-id } {
            active: (if (> replaces-id u0) (get active counts) (+ (get active counts) u1)),
            pending: (- (get pending counts) u1)
        })
        (print { type: "asset-accepted", token-id: token-id, asset-id: asset-id, replaces-id: replaces-id })
        (ok true)
    )
)

(define-public (reject-asset (token-id uint) (index uint) (asset-id uint))
    (let
        (
            (token-owner (unwrap! (nft-get-owner? multi-asset-token token-id) err-invalid-token))
            (counts (default-to { active: u0, pending: u0 } (map-get? asset-count { token-id: token-id })))
        )
        (asserts! (or (is-eq tx-sender token-owner) (is-approved-for-assets token-id tx-sender)) err-not-approved)
        (map-delete pending-assets { token-id: token-id, asset-id: asset-id })
        (map-set asset-count { token-id: token-id } (merge counts { pending: (- (get pending counts) u1) }))
        (print { type: "asset-rejected", token-id: token-id, asset-id: asset-id })
        (ok true)
    )
)

(define-public (reject-all-assets (token-id uint) (max-rejections uint))
    (let
        (
            (token-owner (unwrap! (nft-get-owner? multi-asset-token token-id) err-invalid-token))
        )
        (asserts! (or (is-eq tx-sender token-owner) (is-approved-for-assets token-id tx-sender)) err-not-approved)
        (map-set asset-count { token-id: token-id } { active: u0, pending: u0 })
        (print { type: "asset-rejected", token-id: token-id, asset-id: u0 })
        (ok true)
    )
)

(define-public (set-priority (token-id uint) (priorities (list 10 uint)))
    (let
        (
            (token-owner (unwrap! (nft-get-owner? multi-asset-token token-id) err-invalid-token))
        )
        (asserts! (or (is-eq tx-sender token-owner) (is-approved-for-assets token-id tx-sender)) err-not-approved)
        (print { type: "asset-priority-set", token-id: token-id })
        (ok true)
    )
)

(define-public (approve-for-assets (to principal) (token-id uint))
    (let
        (
            (token-owner (unwrap! (nft-get-owner? multi-asset-token token-id) err-invalid-token))
        )
        (asserts! (is-eq tx-sender token-owner) err-not-token-owner)
        (ok (map-set asset-approvals { token-id: token-id, operator: to } true))
    )
)

(define-public (set-approval-for-all-for-assets (operator principal) (approved bool))
    (begin
        (ok (map-set asset-approvals-for-all { owner: tx-sender, operator: operator } approved))
    )
)

(define-private (is-approved-for-assets (token-id uint) (operator principal))
    (let
        (
            (token-owner (unwrap! (nft-get-owner? multi-asset-token token-id) false))
        )
        (or
            (default-to false (map-get? asset-approvals { token-id: token-id, operator: operator }))
            (default-to false (map-get? asset-approvals-for-all { owner: token-owner, operator: operator }))
        )
    )
)

(define-public (set-token-uri (token-id uint) (uri (string-ascii 256)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set token-uris token-id uri))
    )
)

(define-public (burn (token-id uint))
    (let
        (
            (token-owner (unwrap! (nft-get-owner? multi-asset-token token-id) err-invalid-token))
        )
        (asserts! (is-eq tx-sender token-owner) err-not-token-owner)
        (map-delete asset-count { token-id: token-id })
        (nft-burn? multi-asset-token token-id token-owner)
    )
)
