(define-map identities
    principal
    {
        identity-hash: (buff 32),
        verification-hash: (buff 32),
        verified: bool,
        created-at: uint,
        updated-at: uint
    }
)

(define-map verifiers
    principal
    bool
)

(define-map verification-history
    { identity: principal, index: uint }
    { verifier: principal, timestamp: uint, result: bool }
)

(define-map verification-count principal uint)

(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-not-verifier (err u101))
(define-constant err-identity-exists (err u102))
(define-constant err-identity-not-found (err u103))
(define-constant err-already-verified (err u104))
(define-constant err-verification-failed (err u105))

(define-read-only (get-identity (user principal))
    (ok (map-get? identities user))
)

(define-read-only (is-verified (user principal))
    (match (map-get? identities user)
        identity-data (ok (get verified identity-data))
        (ok false)
    )
)

(define-read-only (is-verifier (verifier principal))
    (ok (default-to false (map-get? verifiers verifier)))
)

(define-read-only (get-verification-history (identity principal) (index uint))
    (ok (map-get? verification-history { identity: identity, index: index }))
)

(define-public (authorize-verifier (verifier principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-owner)
        (map-set verifiers verifier true)
        (ok true)
    )
)

(define-public (revoke-verifier (verifier principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-owner)
        (map-delete verifiers verifier)
        (ok true)
    )
)

(define-public (create-identity (identity-hash (buff 32)) (verification-hash (buff 32)))
    (begin
        (asserts! (is-none (map-get? identities tx-sender)) err-identity-exists)
        (map-set identities tx-sender
            {
                identity-hash: identity-hash,
                verification-hash: verification-hash,
                verified: false,
                created-at: stacks-block-time,
                updated-at: stacks-block-time
            }
        )
        (ok true)
    )
)

(define-public (verify-identity 
    (identity principal)
    (proof-hash (buff 32))
    (signature (buff 65))
)
    (let
        (
            (identity-data (unwrap! (map-get? identities identity) err-identity-not-found))
            (is-authorized-verifier (default-to false (map-get? verifiers tx-sender)))
            (count (default-to u0 (map-get? verification-count identity)))
            (verification-result (is-eq proof-hash (get verification-hash identity-data)))
        )
        (asserts! is-authorized-verifier err-not-verifier)
        (asserts! (not (get verified identity-data)) err-already-verified)
        (map-set verification-history { identity: identity, index: count }
            { verifier: tx-sender, timestamp: stacks-block-time, result: verification-result }
        )
        (map-set verification-count identity (+ count u1))
        (if verification-result
            (begin
                (map-set identities identity
                    (merge identity-data { verified: true, updated-at: stacks-block-time })
                )
                (ok true)
            )
            err-verification-failed
        )
    )
)

(define-public (update-identity (identity-hash (buff 32)) (verification-hash (buff 32)))
    (let
        (
            (identity-data (unwrap! (map-get? identities tx-sender) err-identity-not-found))
        )
        (map-set identities tx-sender
            {
                identity-hash: identity-hash,
                verification-hash: verification-hash,
                verified: false,
                created-at: (get created-at identity-data),
                updated-at: stacks-block-time
            }
        )
        (ok true)
    )
)

(define-public (revoke-identity)
    (let
        (
            (identity-data (unwrap! (map-get? identities tx-sender) err-identity-not-found))
        )
        (map-delete identities tx-sender)
        (ok true)
    )
)
