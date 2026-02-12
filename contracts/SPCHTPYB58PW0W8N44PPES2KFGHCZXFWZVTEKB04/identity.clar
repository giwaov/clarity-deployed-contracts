;; Decentralized Identity Contract
;; Register and verify on-chain identities

(define-constant err-already-registered (err u100))
(define-constant err-not-registered (err u101))
(define-constant err-not-authorized (err u102))

(define-map identities
    principal
    {
        username: (string-ascii 30),
        bio: (string-utf8 500),
        website: (optional (string-ascii 100)),
        email-hash: (optional (buff 32)),
        verified: bool,
        registration-block: uint
    }
)

(define-map username-to-principal (string-ascii 30) principal)
(define-map verifications principal bool)

(define-public (register-identity 
    (username (string-ascii 30))
    (bio (string-utf8 500))
    (website (optional (string-ascii 100)))
    (email-hash (optional (buff 32))))
    (begin
        (asserts! (is-none (map-get? identities tx-sender)) err-already-registered)
        (asserts! (is-none (map-get? username-to-principal username)) err-already-registered)
        
        (map-set identities tx-sender {
            username: username,
            bio: bio,
            website: website,
            email-hash: email-hash,
            verified: false,
            registration-block: block-height
        })
        (map-set username-to-principal username tx-sender)
        (ok true)
    )
)

(define-public (update-identity
    (bio (string-utf8 500))
    (website (optional (string-ascii 100))))
    (let
        (
            (identity (unwrap! (map-get? identities tx-sender) err-not-registered))
        )
        (map-set identities tx-sender (merge identity {
            bio: bio,
            website: website
        }))
        (ok true)
    )
)

(define-public (verify-identity (user principal))
    (let
        (
            (identity (unwrap! (map-get? identities user) err-not-registered))
        )
        ;; In production, add proper verification logic
        (map-set identities user (merge identity {verified: true}))
        (ok true)
    )
)

(define-read-only (get-identity (user principal))
    (map-get? identities user)
)

(define-read-only (resolve-username (username (string-ascii 30)))
    (map-get? username-to-principal username)
)

(define-read-only (is-verified (user principal))
    (match (map-get? identities user)
        identity (get verified identity)
        false
    )
)

(define-read-only (get-username (user principal))
    (match (map-get? identities user)
        identity (some (get username identity))
        none
    )
)
