(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-NAME-TAKEN (err u409))

(define-map name-to-account
    (string-ascii 64)
    principal
)

(define-map account-to-name
    principal
    (string-ascii 64)
)

(define-map account-metadata
    principal
    {
        created-at: uint,
        owner: principal
    }
)

(define-read-only (get-account-by-name (name (string-ascii 64)))
    (ok (map-get? name-to-account name))
)

(define-read-only (get-name-by-account (account principal))
    (ok (map-get? account-to-name account))
)

(define-read-only (get-account-metadata (account principal))
    (ok (map-get? account-metadata account))
)

(define-read-only (is-name-available (name (string-ascii 64)))
    (ok (is-none (map-get? name-to-account name)))
)

(define-public (register-account (name (string-ascii 64)))
    (let
        (
            (existing-name (map-get? account-to-name tx-sender))
            (existing-account (map-get? name-to-account name))
        )
        (asserts! (is-none existing-account) ERR-NAME-TAKEN)
        (match existing-name
            old-name (map-delete name-to-account old-name)
            true
        )
        (map-set name-to-account name tx-sender)
        (map-set account-to-name tx-sender name)
        (map-set account-metadata tx-sender {
            created-at: stacks-block-time,
            owner: tx-sender
        })
        (ok true)
    )
)

(define-public (transfer-account (name (string-ascii 64)) (new-owner principal))
    (let
        (
            (account (unwrap! (map-get? name-to-account name) ERR-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender account) ERR-NOT-AUTHORIZED)
        (map-set name-to-account name new-owner)
        (map-delete account-to-name account)
        (map-set account-to-name new-owner name)
        (map-set account-metadata new-owner {
            created-at: stacks-block-time,
            owner: new-owner
        })
        (ok true)
    )
)

(define-public (release-name)
    (let
        (
            (name (unwrap! (map-get? account-to-name tx-sender) ERR-NOT-FOUND))
        )
        (map-delete name-to-account name)
        (map-delete account-to-name tx-sender)
        (map-delete account-metadata tx-sender)
        (ok true)
    )
)

(define-read-only (get-contract-hash)
    (contract-hash? .name-held-account)
)
