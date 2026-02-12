(define-fungible-token vault-token)

(define-map deposit-requests
    { user: principal, request-id: uint }
    { amount: uint, timestamp: uint, fulfilled: bool }
)

(define-map redeem-requests
    { user: principal, request-id: uint }
    { shares: uint, timestamp: uint, fulfilled: bool }
)

(define-map user-balances principal uint)
(define-map pending-deposits principal uint)
(define-map pending-redeems principal uint)

(define-data-var total-assets uint u0)
(define-data-var total-shares uint u0)
(define-data-var deposit-request-counter uint u0)
(define-data-var redeem-request-counter uint u0)

(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-invalid-amount (err u101))
(define-constant err-request-not-found (err u102))
(define-constant err-already-fulfilled (err u103))
(define-constant err-insufficient-shares (err u104))

(define-read-only (get-total-assets)
    (ok (var-get total-assets))
)

(define-read-only (get-total-shares)
    (ok (var-get total-shares))
)

(define-read-only (get-balance (user principal))
    (ok (default-to u0 (map-get? user-balances user)))
)

(define-read-only (get-deposit-request (user principal) (request-id uint))
    (ok (map-get? deposit-requests { user: user, request-id: request-id }))
)

(define-read-only (get-redeem-request (user principal) (request-id uint))
    (ok (map-get? redeem-requests { user: user, request-id: request-id }))
)

(define-public (request-deposit (amount uint))
    (let
        (
            (request-id (var-get deposit-request-counter))
        )
        (asserts! (> amount u0) err-invalid-amount)
        (map-set deposit-requests { user: tx-sender, request-id: request-id }
            { amount: amount, timestamp: stacks-block-time, fulfilled: false }
        )
        (map-set pending-deposits tx-sender amount)
        (var-set deposit-request-counter (+ request-id u1))
        (ok request-id)
    )
)

(define-public (fulfill-deposit (user principal) (request-id uint))
    (let
        (
            (request (unwrap! (map-get? deposit-requests { user: user, request-id: request-id }) err-request-not-found))
            (amount (get amount request))
            (current-total-assets (var-get total-assets))
            (current-total-shares (var-get total-shares))
            (shares-to-mint (if (is-eq current-total-shares u0)
                amount
                (/ (* amount current-total-shares) current-total-assets)
            ))
            (current-balance (default-to u0 (map-get? user-balances user)))
        )
        (asserts! (is-eq tx-sender contract-owner) err-not-owner)
        (asserts! (not (get fulfilled request)) err-already-fulfilled)
        (map-set deposit-requests { user: user, request-id: request-id }
            (merge request { fulfilled: true })
        )
        (try! (ft-mint? vault-token shares-to-mint user))
        (map-set user-balances user (+ current-balance shares-to-mint))
        (var-set total-assets (+ current-total-assets amount))
        (var-set total-shares (+ current-total-shares shares-to-mint))
        (map-delete pending-deposits user)
        (ok shares-to-mint)
    )
)

(define-public (request-redeem (shares uint))
    (let
        (
            (request-id (var-get redeem-request-counter))
            (balance (default-to u0 (map-get? user-balances tx-sender)))
        )
        (asserts! (>= balance shares) err-insufficient-shares)
        (map-set redeem-requests { user: tx-sender, request-id: request-id }
            { shares: shares, timestamp: stacks-block-time, fulfilled: false }
        )
        (map-set pending-redeems tx-sender shares)
        (var-set redeem-request-counter (+ request-id u1))
        (ok request-id)
    )
)

(define-public (fulfill-redeem (user principal) (request-id uint))
    (let
        (
            (request (unwrap! (map-get? redeem-requests { user: user, request-id: request-id }) err-request-not-found))
            (shares (get shares request))
            (current-total-assets (var-get total-assets))
            (current-total-shares (var-get total-shares))
            (assets-to-return (/ (* shares current-total-assets) current-total-shares))
            (current-balance (default-to u0 (map-get? user-balances user)))
        )
        (asserts! (is-eq tx-sender contract-owner) err-not-owner)
        (asserts! (not (get fulfilled request)) err-already-fulfilled)
        (map-set redeem-requests { user: user, request-id: request-id }
            (merge request { fulfilled: true })
        )
        (try! (ft-burn? vault-token shares user))
        (map-set user-balances user (- current-balance shares))
        (var-set total-assets (- current-total-assets assets-to-return))
        (var-set total-shares (- current-total-shares shares))
        (map-delete pending-redeems user)
        (ok assets-to-return)
    )
)
