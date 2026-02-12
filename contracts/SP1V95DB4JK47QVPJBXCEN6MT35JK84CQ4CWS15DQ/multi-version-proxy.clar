(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-VERSION-NOT-FOUND (err u404))
(define-constant ERR-INVALID-VERSION (err u400))

(define-data-var owner principal tx-sender)
(define-data-var current-version uint u0)

(define-map implementations
    uint
    principal
)

(define-map version-metadata
    uint
    {
        contract: principal,
        timestamp: uint,
        enabled: bool
    }
)

(define-read-only (get-owner)
    (ok (var-get owner))
)

(define-read-only (get-current-version)
    (ok (var-get current-version))
)

(define-read-only (get-implementation (version uint))
    (ok (map-get? implementations version))
)

(define-read-only (get-version-metadata (version uint))
    (ok (map-get? version-metadata version))
)

(define-read-only (is-version-enabled (version uint))
    (match (map-get? version-metadata version)
        metadata (ok (get enabled metadata))
        (ok false)
    )
)

(define-public (set-owner (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get owner)) ERR-NOT-AUTHORIZED)
        (ok (var-set owner new-owner))
    )
)

(define-public (add-version (implementation principal))
    (let
        (
            (new-version (+ (var-get current-version) u1))
        )
        (asserts! (is-eq tx-sender (var-get owner)) ERR-NOT-AUTHORIZED)
        (map-set implementations new-version implementation)
        (map-set version-metadata new-version {
            contract: implementation,
            timestamp: stacks-block-time,
            enabled: true
        })
        (var-set current-version new-version)
        (ok new-version)
    )
)

(define-public (toggle-version (version uint))
    (begin
        (asserts! (is-eq tx-sender (var-get owner)) ERR-NOT-AUTHORIZED)
        (match (map-get? version-metadata version)
            metadata (ok (map-set version-metadata version (merge metadata {enabled: (not (get enabled metadata))})))
            ERR-VERSION-NOT-FOUND
        )
    )
)

(define-public (set-current-version (version uint))
    (begin
        (asserts! (is-eq tx-sender (var-get owner)) ERR-NOT-AUTHORIZED)
        (asserts! (is-some (map-get? implementations version)) ERR-VERSION-NOT-FOUND)
        (match (map-get? version-metadata version)
            metadata (begin
                (asserts! (get enabled metadata) ERR-INVALID-VERSION)
                (ok (var-set current-version version))
            )
            ERR-VERSION-NOT-FOUND
        )
    )
)

(define-read-only (get-contract-hash)
    (contract-hash? .multi-version-proxy)
)
