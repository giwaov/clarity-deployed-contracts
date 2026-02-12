(define-non-fungible-token future-rewards-nft uint)

(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))

(define-data-var token-id-nonce uint u0)

(define-map token-reward-allocation
    uint
    {
        total-allocation: uint,
        claimed-amount: uint,
        beneficiary: principal
    }
)

(define-map historical-owners
    {token-id: uint, owner: principal}
    uint
)

(define-read-only (get-last-token-id)
    (ok (var-get token-id-nonce))
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? future-rewards-nft token-id))
)

(define-read-only (get-reward-allocation (token-id uint))
    (ok (map-get? token-reward-allocation token-id))
)

(define-read-only (get-claimable-amount (token-id uint))
    (match (map-get? token-reward-allocation token-id)
        allocation (ok (- (get total-allocation allocation) (get claimed-amount allocation)))
        ERR-NOT-FOUND
    )
)

(define-read-only (get-historical-ownership (token-id uint) (owner principal))
    (ok (default-to u0 (map-get? historical-owners {token-id: token-id, owner: owner})))
)

(define-public (mint (total-allocation uint) (beneficiary principal))
    (let
        (
            (new-id (+ (var-get token-id-nonce) u1))
        )
        (try! (nft-mint? future-rewards-nft new-id tx-sender))
        (map-set token-reward-allocation new-id {
            total-allocation: total-allocation,
            claimed-amount: u0,
            beneficiary: beneficiary
        })
        (map-set historical-owners {token-id: new-id, owner: tx-sender} stacks-block-time)
        (var-set token-id-nonce new-id)
        (ok new-id)
    )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
        (map-set historical-owners {token-id: token-id, owner: recipient} stacks-block-time)
        (nft-transfer? future-rewards-nft token-id sender recipient)
    )
)

(define-public (claim-rewards (token-id uint))
    (let
        (
            (allocation (unwrap! (map-get? token-reward-allocation token-id) ERR-NOT-FOUND))
            (claimable (- (get total-allocation allocation) (get claimed-amount allocation)))
        )
        (asserts! (is-eq tx-sender (get beneficiary allocation)) ERR-NOT-AUTHORIZED)
        (map-set token-reward-allocation token-id (merge allocation {
            claimed-amount: (get total-allocation allocation)
        }))
        (ok claimable)
    )
)

(define-public (set-beneficiary (token-id uint) (new-beneficiary principal))
    (let
        (
            (owner (unwrap! (nft-get-owner? future-rewards-nft token-id) ERR-NOT-FOUND))
            (allocation (unwrap! (map-get? token-reward-allocation token-id) ERR-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
        (ok (map-set token-reward-allocation token-id (merge allocation {beneficiary: new-beneficiary})))
    )
)

(define-read-only (get-contract-hash)
    (contract-hash? .future-rewards-nft)
)
