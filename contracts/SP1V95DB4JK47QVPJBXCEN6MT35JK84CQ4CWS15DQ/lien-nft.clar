(define-non-fungible-token lien-token uint)

(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-LIEN-ACTIVE (err u405))

(define-data-var token-id-nonce uint u0)

(define-map liens
    uint
    {
        debtor: principal,
        creditor: principal,
        amount: uint,
        nft-contract: principal,
        nft-id: uint,
        active: bool
    }
)

(define-read-only (get-last-token-id)
    (ok (var-get token-id-nonce))
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? lien-token token-id))
)

(define-read-only (get-lien (token-id uint))
    (ok (map-get? liens token-id))
)

(define-read-only (is-lien-active (token-id uint))
    (match (map-get? liens token-id)
        lien (ok (get active lien))
        ERR-NOT-FOUND
    )
)

(define-public (create-lien
    (debtor principal)
    (amount uint)
    (nft-contract principal)
    (nft-id uint)
)
    (let
        (
            (new-id (+ (var-get token-id-nonce) u1))
        )
        (try! (nft-mint? lien-token new-id tx-sender))
        (map-set liens new-id {
            debtor: debtor,
            creditor: tx-sender,
            amount: amount,
            nft-contract: nft-contract,
            nft-id: nft-id,
            active: true
        })
        (var-set token-id-nonce new-id)
        (ok new-id)
    )
)

(define-public (release-lien (token-id uint))
    (let
        (
            (lien (unwrap! (map-get? liens token-id) ERR-NOT-FOUND))
            (owner (unwrap! (nft-get-owner? lien-token token-id) ERR-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
        (asserts! (get active lien) ERR-NOT-FOUND)
        (ok (map-set liens token-id (merge lien {active: false})))
    )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
        (nft-transfer? lien-token token-id sender recipient)
    )
)

(define-public (foreclose-lien (token-id uint))
    (let
        (
            (lien (unwrap! (map-get? liens token-id) ERR-NOT-FOUND))
            (owner (unwrap! (nft-get-owner? lien-token token-id) ERR-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
        (asserts! (get active lien) ERR-NOT-FOUND)
        (map-set liens token-id (merge lien {active: false}))
        (ok true)
    )
)

(define-read-only (get-contract-hash)
    (contract-hash? .lien-nft)
)
