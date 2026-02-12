(define-non-fungible-token flashloan-nft uint)

(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-LOAN-ACTIVE (err u405))
(define-constant ERR-INVALID-RETURN (err u406))

(define-data-var token-id-nonce uint u0)

(define-map active-loans
    uint
    {
        borrower: principal,
        loan-block: uint,
        fee: uint
    }
)

(define-map loan-receivers
    principal
    bool
)

(define-read-only (get-last-token-id)
    (ok (var-get token-id-nonce))
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? flashloan-nft token-id))
)

(define-read-only (get-active-loan (token-id uint))
    (ok (map-get? active-loans token-id))
)

(define-read-only (is-loan-active (token-id uint))
    (ok (is-some (map-get? active-loans token-id)))
)

(define-public (mint)
    (let
        (
            (new-id (+ (var-get token-id-nonce) u1))
        )
        (try! (nft-mint? flashloan-nft new-id tx-sender))
        (var-set token-id-nonce new-id)
        (ok new-id)
    )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? active-loans token-id)) ERR-LOAN-ACTIVE)
        (nft-transfer? flashloan-nft token-id sender recipient)
    )
)

(define-public (flash-loan (token-id uint) (receiver principal))
    (let
        (
            (owner (unwrap! (nft-get-owner? flashloan-nft token-id) ERR-NOT-FOUND))
            (current-block stacks-block-height)
        )
        (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? active-loans token-id)) ERR-LOAN-ACTIVE)
        (map-set active-loans token-id {
            borrower: receiver,
            loan-block: current-block,
            fee: u0
        })
        (try! (nft-transfer? flashloan-nft token-id owner receiver))
        (ok true)
    )
)

(define-public (return-flash-loan (token-id uint) (fee uint))
    (let
        (
            (loan (unwrap! (map-get? active-loans token-id) ERR-NOT-FOUND))
            (current-owner (unwrap! (nft-get-owner? flashloan-nft token-id) ERR-NOT-FOUND))
            (current-block stacks-block-height)
        )
        (asserts! (is-eq tx-sender (get borrower loan)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq current-block (get loan-block loan)) ERR-INVALID-RETURN)
        (map-delete active-loans token-id)
        (try! (nft-transfer? flashloan-nft token-id current-owner tx-sender))
        (ok true)
    )
)

(define-public (register-receiver)
    (begin
        (ok (map-set loan-receivers tx-sender true))
    )
)

(define-read-only (get-contract-hash)
    (contract-hash? .flashloanable-nft)
)
