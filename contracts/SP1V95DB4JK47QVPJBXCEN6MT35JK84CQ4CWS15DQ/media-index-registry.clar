(define-map media-commits 
    { asset-cid: (string-ascii 64) }
    { committer: principal, timestamp: uint, data: (string-utf8 256) }
)

(define-map user-commits
    { user: principal, index: uint }
    (string-ascii 64)
)

(define-map commit-count principal uint)

(define-constant err-invalid-cid (err u100))
(define-constant err-commit-exists (err u101))
(define-constant err-not-found (err u102))

(define-read-only (get-commit (asset-cid (string-ascii 64)))
    (ok (map-get? media-commits { asset-cid: asset-cid }))
)

(define-read-only (get-user-commit (user principal) (index uint))
    (ok (map-get? user-commits { user: user, index: index }))
)

(define-read-only (get-commit-count (user principal))
    (ok (default-to u0 (map-get? commit-count user)))
)

(define-read-only (get-block-time)
    (ok stacks-block-time)
)

(define-public (commit (asset-cid (string-ascii 64)) (commit-data (string-utf8 256)))
    (let
        (
            (current-count (default-to u0 (map-get? commit-count tx-sender)))
            (timestamp stacks-block-time)
        )
        (asserts! (> (len asset-cid) u0) err-invalid-cid)
        (asserts! (is-none (map-get? media-commits { asset-cid: asset-cid })) err-commit-exists)
        (map-set media-commits 
            { asset-cid: asset-cid }
            { committer: tx-sender, timestamp: timestamp, data: commit-data }
        )
        (map-set user-commits
            { user: tx-sender, index: current-count }
            asset-cid
        )
        (map-set commit-count tx-sender (+ current-count u1))
        (ok true)
    )
)

(define-public (verify-commit (asset-cid (string-ascii 64)) (expected-committer principal))
    (let
        (
            (commit-data (unwrap! (map-get? media-commits { asset-cid: asset-cid }) err-not-found))
        )
        (ok (is-eq (get committer commit-data) expected-committer))
    )
)
