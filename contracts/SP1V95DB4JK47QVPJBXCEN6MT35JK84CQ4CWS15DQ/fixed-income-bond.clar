(define-fungible-token bond)

(define-map bond-metadata
    { bond-id: (string-ascii 12) }
    {
        issuer: principal,
        isin: (string-ascii 12),
        coupon-rate: uint,
        maturity-date: uint,
        denomination: uint,
        issue-date: uint
    }
)

(define-map bond-principals
    { bond-id: (string-ascii 12), holder: principal }
    uint
)

(define-map user-bonds
    { holder: principal, index: uint }
    (string-ascii 12)
)

(define-map bond-count principal uint)

(define-constant err-not-issuer (err u100))
(define-constant err-bond-not-found (err u101))
(define-constant err-invalid-amount (err u102))
(define-constant err-not-matured (err u103))
(define-constant err-insufficient-balance (err u104))

(define-read-only (get-bond-info (bond-id (string-ascii 12)))
    (ok (map-get? bond-metadata { bond-id: bond-id }))
)

(define-read-only (get-principal-of (bond-id (string-ascii 12)) (holder principal))
    (ok (default-to u0 (map-get? bond-principals { bond-id: bond-id, holder: holder })))
)

(define-read-only (get-coupon-rate (bond-id (string-ascii 12)))
    (match (map-get? bond-metadata { bond-id: bond-id })
        bond-data (ok (get coupon-rate bond-data))
        err-bond-not-found
    )
)

(define-read-only (get-maturity-date (bond-id (string-ascii 12)))
    (match (map-get? bond-metadata { bond-id: bond-id })
        bond-data (ok (get maturity-date bond-data))
        err-bond-not-found
    )
)

(define-public (issue-bond 
    (bond-id (string-ascii 12))
    (isin (string-ascii 12))
    (coupon-rate uint)
    (maturity-date uint)
    (denomination uint)
)
    (begin
        (asserts! (is-none (map-get? bond-metadata { bond-id: bond-id })) err-bond-not-found)
        (map-set bond-metadata
            { bond-id: bond-id }
            {
                issuer: tx-sender,
                isin: isin,
                coupon-rate: coupon-rate,
                maturity-date: maturity-date,
                denomination: denomination,
                issue-date: stacks-block-time
            }
        )
        (ok true)
    )
)

(define-public (purchase-bond (bond-id (string-ascii 12)) (amount uint))
    (let
        (
            (bond-info (unwrap! (map-get? bond-metadata { bond-id: bond-id }) err-bond-not-found))
            (current-principal (default-to u0 (map-get? bond-principals { bond-id: bond-id, holder: tx-sender })))
            (current-count (default-to u0 (map-get? bond-count tx-sender)))
        )
        (asserts! (> amount u0) err-invalid-amount)
        (map-set bond-principals
            { bond-id: bond-id, holder: tx-sender }
            (+ current-principal amount)
        )
        (if (is-eq current-principal u0)
            (begin
                (map-set user-bonds { holder: tx-sender, index: current-count } bond-id)
                (map-set bond-count tx-sender (+ current-count u1))
            )
            true
        )
        (ok true)
    )
)

(define-public (redeem-bond (bond-id (string-ascii 12)))
    (let
        (
            (bond-info (unwrap! (map-get? bond-metadata { bond-id: bond-id }) err-bond-not-found))
            (principal-amount (unwrap! (map-get? bond-principals { bond-id: bond-id, holder: tx-sender }) err-insufficient-balance))
        )
        (asserts! (>= stacks-block-time (get maturity-date bond-info)) err-not-matured)
        (asserts! (> principal-amount u0) err-insufficient-balance)
        (map-delete bond-principals { bond-id: bond-id, holder: tx-sender })
        (ok principal-amount)
    )
)
