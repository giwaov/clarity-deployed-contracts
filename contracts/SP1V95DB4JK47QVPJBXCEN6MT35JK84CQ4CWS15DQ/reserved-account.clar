(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ACCOUNT-RESERVED (err u409))

(define-map reserved-accounts
    principal
    {
        owner: principal,
        reserved-at: uint,
        release-time: uint,
        metadata: (string-utf8 256)
    }
)

(define-map account-reservations
    principal
    (list 10 principal)
)

(define-map reservation-registry
    (string-ascii 64)
    principal
)

(define-read-only (is-reserved (account principal))
    (ok (is-some (map-get? reserved-accounts account)))
)

(define-read-only (get-reservation (account principal))
    (ok (map-get? reserved-accounts account))
)

(define-read-only (get-owner-reservations (owner principal))
    (ok (default-to (list) (map-get? account-reservations owner)))
)

(define-read-only (get-account-by-name (name (string-ascii 64)))
    (ok (map-get? reservation-registry name))
)

(define-public (reserve-account
    (account principal)
    (release-time uint)
    (metadata (string-utf8 256))
)
    (let
        (
            (owner-accounts (default-to (list) (map-get? account-reservations tx-sender)))
        )
        (asserts! (is-none (map-get? reserved-accounts account)) ERR-ACCOUNT-RESERVED)
        (map-set reserved-accounts account {
            owner: tx-sender,
            reserved-at: stacks-block-time,
            release-time: release-time,
            metadata: metadata
        })
        (map-set account-reservations tx-sender 
            (unwrap-panic (as-max-len? (append owner-accounts account) u10))
        )
        (ok true)
    )
)

(define-public (release-reservation (account principal))
    (let
        (
            (reservation (unwrap! (map-get? reserved-accounts account) ERR-NOT-FOUND))
        )
        (asserts! (or 
            (is-eq tx-sender (get owner reservation))
            (>= stacks-block-time (get release-time reservation))
        ) ERR-NOT-AUTHORIZED)
        (map-delete reserved-accounts account)
        (ok true)
    )
)

(define-public (transfer-reservation (account principal) (new-owner principal))
    (let
        (
            (reservation (unwrap! (map-get? reserved-accounts account) ERR-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender (get owner reservation)) ERR-NOT-AUTHORIZED)
        (ok (map-set reserved-accounts account (merge reservation {owner: new-owner})))
    )
)

(define-public (extend-reservation (account principal) (new-release-time uint))
    (let
        (
            (reservation (unwrap! (map-get? reserved-accounts account) ERR-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender (get owner reservation)) ERR-NOT-AUTHORIZED)
        (ok (map-set reserved-accounts account (merge reservation {release-time: new-release-time})))
    )
)

(define-public (register-name (name (string-ascii 64)) (account principal))
    (let
        (
            (reservation (unwrap! (map-get? reserved-accounts account) ERR-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender (get owner reservation)) ERR-NOT-AUTHORIZED)
        (ok (map-set reservation-registry name account))
    )
)

(define-read-only (get-contract-hash)
    (contract-hash? .reserved-account)
)
