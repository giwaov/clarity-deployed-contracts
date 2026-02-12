(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))

(define-map account-metadata
    principal
    {
        name: (string-utf8 64),
        authentication-methods: (list 5 (string-ascii 32)),
        recovery-address: (optional principal),
        created-at: uint
    }
)

(define-map authentication-keys
    {account: principal, method: (string-ascii 32)}
    (buff 65)
)

(define-map authentication-history
    {account: principal, timestamp: uint}
    {
        method: (string-ascii 32),
        success: bool
    }
)

(define-read-only (get-metadata (account principal))
    (ok (map-get? account-metadata account))
)

(define-read-only (get-authentication-key (account principal) (method (string-ascii 32)))
    (ok (map-get? authentication-keys {account: account, method: method}))
)

(define-read-only (has-authentication-method (account principal) (method (string-ascii 32)))
    (match (map-get? account-metadata account)
        metadata (ok (is-some (index-of? (get authentication-methods metadata) method)))
        (ok false)
    )
)

(define-public (register-account
    (name (string-utf8 64))
    (methods (list 5 (string-ascii 32)))
    (recovery-address (optional principal))
)
    (begin
        (map-set account-metadata tx-sender {
            name: name,
            authentication-methods: methods,
            recovery-address: recovery-address,
            created-at: stacks-block-time
        })
        (ok true)
    )
)

(define-public (add-authentication-method
    (method (string-ascii 32))
    (key (buff 65))
)
    (let
        (
            (metadata (unwrap! (map-get? account-metadata tx-sender) ERR-NOT-FOUND))
            (current-methods (get authentication-methods metadata))
        )
        (map-set authentication-keys {account: tx-sender, method: method} key)
        (ok (map-set account-metadata tx-sender (merge metadata {
            authentication-methods: (unwrap-panic (as-max-len? (append current-methods method) u5))
        })))
    )
)

(define-public (remove-authentication-method (method (string-ascii 32)))
    (let
        (
            (metadata (unwrap! (map-get? account-metadata tx-sender) ERR-NOT-FOUND))
        )
        (map-delete authentication-keys {account: tx-sender, method: method})
        (ok true)
    )
)

(define-public (update-recovery-address (new-recovery principal))
    (let
        (
            (metadata (unwrap! (map-get? account-metadata tx-sender) ERR-NOT-FOUND))
        )
        (ok (map-set account-metadata tx-sender (merge metadata {recovery-address: (some new-recovery)})))
    )
)

(define-public (log-authentication (method (string-ascii 32)) (success bool))
    (begin
        (map-set authentication-history 
            {account: tx-sender, timestamp: stacks-block-time}
            {method: method, success: success}
        )
        (ok true)
    )
)

(define-read-only (get-contract-hash)
    (contract-hash? .aa-metadata-for-auth)
)
