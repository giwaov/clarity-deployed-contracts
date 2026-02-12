(define-non-fungible-token parent-nft uint)
(define-non-fungible-token child-nft uint)

(define-data-var last-parent-id uint u0)
(define-data-var last-child-id uint u0)

(define-map parent-metadata
    uint
    { owner: principal, children: (list 50 uint) }
)

(define-map child-metadata
    uint
    { owner: principal, parent: (optional uint), pending-parent: (optional uint) }
)

(define-map proposed-transfers
    { child-id: uint, parent-id: uint }
    bool
)

(define-constant err-not-owner (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-child (err u102))
(define-constant err-no-proposal (err u103))
(define-constant err-max-children (err u104))

(define-read-only (get-parent-info (parent-id uint))
    (ok (map-get? parent-metadata parent-id))
)

(define-read-only (get-child-info (child-id uint))
    (ok (map-get? child-metadata child-id))
)

(define-read-only (get-parent-of-child (child-id uint))
    (match (map-get? child-metadata child-id)
        child-data (ok (get parent child-data))
        err-not-found
    )
)

(define-public (mint-parent (recipient principal))
    (let
        (
            (parent-id (+ (var-get last-parent-id) u1))
        )
        (try! (nft-mint? parent-nft parent-id recipient))
        (map-set parent-metadata parent-id
            { owner: recipient, children: (list) }
        )
        (var-set last-parent-id parent-id)
        (ok parent-id)
    )
)

(define-public (mint-child (recipient principal))
    (let
        (
            (child-id (+ (var-get last-child-id) u1))
        )
        (try! (nft-mint? child-nft child-id recipient))
        (map-set child-metadata child-id
            { owner: recipient, parent: none, pending-parent: none }
        )
        (var-set last-child-id child-id)
        (ok child-id)
    )
)

(define-public (propose-add-child (parent-id uint) (child-id uint))
    (let
        (
            (parent-data (unwrap! (map-get? parent-metadata parent-id) err-not-found))
            (child-data (unwrap! (map-get? child-metadata child-id) err-not-found))
        )
        (asserts! (is-eq tx-sender (get owner parent-data)) err-not-owner)
        (asserts! (is-none (get parent child-data)) err-already-child)
        (map-set proposed-transfers { child-id: child-id, parent-id: parent-id } true)
        (map-set child-metadata child-id
            (merge child-data { pending-parent: (some parent-id) })
        )
        (ok true)
    )
)

(define-public (accept-child (parent-id uint) (child-id uint))
    (let
        (
            (parent-data (unwrap! (map-get? parent-metadata parent-id) err-not-found))
            (child-data (unwrap! (map-get? child-metadata child-id) err-not-found))
            (children-list (get children parent-data))
        )
        (asserts! (is-eq tx-sender (get owner child-data)) err-not-owner)
        (asserts! (is-some (map-get? proposed-transfers { child-id: child-id, parent-id: parent-id })) err-no-proposal)
        (asserts! (< (len children-list) u50) err-max-children)
        (map-set parent-metadata parent-id
            { owner: (get owner parent-data), children: (unwrap-panic (as-max-len? (append children-list child-id) u50)) }
        )
        (map-set child-metadata child-id
            { owner: (get owner child-data), parent: (some parent-id), pending-parent: none }
        )
        (map-delete proposed-transfers { child-id: child-id, parent-id: parent-id })
        (ok true)
    )
)

(define-public (remove-child (parent-id uint) (child-id uint))
    (let
        (
            (parent-data (unwrap! (map-get? parent-metadata parent-id) err-not-found))
            (child-data (unwrap! (map-get? child-metadata child-id) err-not-found))
        )
        (asserts! (is-eq tx-sender (get owner parent-data)) err-not-owner)
        (map-set child-metadata child-id
            { owner: (get owner child-data), parent: none, pending-parent: none }
        )
        (ok true)
    )
)
