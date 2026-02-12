(impl-trait .orange-sip009-nft-trait-v19.nft-trait)
(define-non-fungible-token orange-nft uint)
(define-data-var contract-owner principal tx-sender)
(define-data-var last-token-id uint u0)

(define-read-only (get-last-token-id) (ok (var-get last-token-id)))
(define-read-only (get-token-uri (token-id uint)) (ok none))
(define-read-only (get-owner (token-id uint)) (ok (nft-get-owner? orange-nft token-id)))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        ;; Caller-Identity Pattern: allow if tx-sender is sender OR if the calling contract is the sender
        (asserts! (or (is-eq tx-sender sender) (is-eq contract-caller sender)) (err u101))
        (nft-transfer? orange-nft token-id sender recipient)
    )
)

(define-public (mint (recipient principal))
    (let ((token-id (+ (var-get last-token-id) u1)))
        (asserts! (is-eq tx-sender (var-get contract-owner)) (err u100))
        (try! (nft-mint? orange-nft token-id recipient))
        (var-set last-token-id token-id)
        (ok token-id)
    )
)
