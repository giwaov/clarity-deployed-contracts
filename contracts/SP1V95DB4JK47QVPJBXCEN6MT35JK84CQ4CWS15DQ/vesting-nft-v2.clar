(define-non-fungible-token vesting-nft uint)

(define-map vesting-schedules
    uint
    {
        payout-token: principal,
        total-amount: uint,
        claimed-amount: uint,
        vesting-start: uint,
        vesting-end: uint
    }
)

(define-map claim-approvals { token-id: uint, operator: principal } bool)
(define-map claim-approvals-for-all { owner: principal, operator: principal } bool)
(define-map token-uris uint (string-ascii 256))

(define-data-var token-id-nonce uint u0)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-invalid-token (err u102))
(define-constant err-not-approved (err u103))
(define-constant err-nothing-to-claim (err u104))
(define-constant err-transfer-failed (err u105))

(define-read-only (get-last-token-id)
    (ok (var-get token-id-nonce))
)

(define-read-only (get-token-uri (token-id uint))
    (ok (map-get? token-uris token-id))
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? vesting-nft token-id))
)

(define-read-only (get-vesting-period (token-id uint))
    (let
        (
            (schedule (unwrap! (map-get? vesting-schedules token-id) err-invalid-token))
        )
        (ok { vesting-start: (get vesting-start schedule), vesting-end: (get vesting-end schedule) })
    )
)

(define-read-only (claimed-payout (token-id uint))
    (let
        (
            (schedule (unwrap! (map-get? vesting-schedules token-id) err-invalid-token))
        )
        (ok (get claimed-amount schedule))
    )
)

(define-read-only (vested-payout (token-id uint))
    (vested-payout-at-time token-id stacks-block-time)
)

(define-read-only (vested-payout-at-time (token-id uint) (timestamp uint))
    (let
        (
            (schedule (unwrap! (map-get? vesting-schedules token-id) err-invalid-token))
            (vesting-start (get vesting-start schedule))
            (vesting-end (get vesting-end schedule))
            (total-amount (get total-amount schedule))
        )
        (if (<= timestamp vesting-start)
            (ok u0)
            (if (>= timestamp vesting-end)
                (ok total-amount)
                (ok (/ (* total-amount (- timestamp vesting-start)) (- vesting-end vesting-start)))
            )
        )
    )
)

(define-read-only (claimable-payout (token-id uint))
    (let
        (
            (schedule (unwrap! (map-get? vesting-schedules token-id) err-invalid-token))
            (vested (unwrap-panic (vested-payout token-id)))
            (claimed (get claimed-amount schedule))
        )
        (ok (if (> vested claimed) (- vested claimed) u0))
    )
)

(define-read-only (vesting-payout (token-id uint))
    (let
        (
            (schedule (unwrap! (map-get? vesting-schedules token-id) err-invalid-token))
            (total (get total-amount schedule))
            (vested (unwrap-panic (vested-payout token-id)))
        )
        (ok (- total vested))
    )
)

(define-read-only (payout-token (token-id uint))
    (let
        (
            (schedule (unwrap! (map-get? vesting-schedules token-id) err-invalid-token))
        )
        (ok (get payout-token schedule))
    )
)

(define-read-only (is-claim-approved-for-all (owner principal) (operator principal))
    (ok (default-to false (map-get? claim-approvals-for-all { owner: owner, operator: operator })))
)

(define-read-only (get-claim-approved (token-id uint))
    (ok none)
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (nft-transfer? vesting-nft token-id sender recipient)
    )
)

(define-public (mint (recipient principal) (payout-token-contract principal) (total-amount uint) (vesting-start uint) (vesting-end uint))
    (let
        (
            (new-token-id (+ (var-get token-id-nonce) u1))
        )
        (try! (nft-mint? vesting-nft new-token-id recipient))
        (map-set vesting-schedules new-token-id {
            payout-token: payout-token-contract,
            total-amount: total-amount,
            claimed-amount: u0,
            vesting-start: vesting-start,
            vesting-end: vesting-end
        })
        (var-set token-id-nonce new-token-id)
        (ok new-token-id)
    )
)

(define-public (claim (token-id uint))
    (let
        (
            (token-owner (unwrap! (nft-get-owner? vesting-nft token-id) err-invalid-token))
            (schedule (unwrap! (map-get? vesting-schedules token-id) err-invalid-token))
            (claimable (unwrap-panic (claimable-payout token-id)))
        )
        (asserts! (or (is-eq tx-sender token-owner) (is-approved-claimer token-id tx-sender)) err-not-approved)
        (asserts! (> claimable u0) err-nothing-to-claim)
        (map-set vesting-schedules token-id (merge schedule { claimed-amount: (+ (get claimed-amount schedule) claimable) }))
        (print { type: "payout-claimed", token-id: token-id, recipient: token-owner, claim-amount: claimable })
        (ok claimable)
    )
)

(define-public (set-claim-approval-for-all (operator principal) (approved bool))
    (begin
        (ok (map-set claim-approvals-for-all { owner: tx-sender, operator: operator } approved))
    )
)

(define-public (set-claim-approval (operator principal) (approved bool) (token-id uint))
    (let
        (
            (token-owner (unwrap! (nft-get-owner? vesting-nft token-id) err-invalid-token))
        )
        (asserts! (is-eq tx-sender token-owner) err-not-token-owner)
        (ok (map-set claim-approvals { token-id: token-id, operator: operator } approved))
    )
)

(define-private (is-approved-claimer (token-id uint) (operator principal))
    (let
        (
            (token-owner (unwrap! (nft-get-owner? vesting-nft token-id) false))
        )
        (or
            (default-to false (map-get? claim-approvals { token-id: token-id, operator: operator }))
            (default-to false (map-get? claim-approvals-for-all { owner: token-owner, operator: operator }))
        )
    )
)

(define-public (set-token-uri (token-id uint) (uri (string-ascii 256)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set token-uris token-id uri))
    )
)

(define-public (burn (token-id uint))
    (let
        (
            (token-owner (unwrap! (nft-get-owner? vesting-nft token-id) err-invalid-token))
        )
        (asserts! (is-eq tx-sender token-owner) err-not-token-owner)
        (map-delete vesting-schedules token-id)
        (nft-burn? vesting-nft token-id token-owner)
    )
)
