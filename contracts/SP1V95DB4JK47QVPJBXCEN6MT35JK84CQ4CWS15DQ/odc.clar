(define-map data-points
    (buff 32)
    { owner: principal, data: (buff 1024), timestamp: uint }
)

(define-map data-objects
    { object-id: (string-ascii 64) }
    { creator: principal, points: (list 10 (buff 32)), metadata: (string-utf8 256) }
)

(define-map data-managers
    { manager-id: principal }
    { authorized: bool, objects: (list 100 (string-ascii 64)) }
)

(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-point-exists (err u102))
(define-constant err-not-found (err u103))
(define-constant err-invalid-data (err u104))

(define-read-only (get-data-point (point-id (buff 32)))
    (ok (map-get? data-points point-id))
)

(define-read-only (get-data-object (object-id (string-ascii 64)))
    (ok (map-get? data-objects { object-id: object-id }))
)

(define-read-only (get-manager (manager-id principal))
    (ok (map-get? data-managers { manager-id: manager-id }))
)

(define-read-only (is-manager-authorized (manager-id principal))
    (match (map-get? data-managers { manager-id: manager-id })
        manager-data (ok (get authorized manager-data))
        (ok false)
    )
)

(define-public (create-data-point (point-id (buff 32)) (data (buff 1024)))
    (begin
        (asserts! (is-none (map-get? data-points point-id)) err-point-exists)
        (asserts! (> (len data) u0) err-invalid-data)
        (map-set data-points point-id
            { owner: tx-sender, data: data, timestamp: stacks-block-time }
        )
        (ok true)
    )
)

(define-public (create-data-object 
    (object-id (string-ascii 64))
    (points (list 10 (buff 32)))
    (metadata (string-utf8 256))
)
    (begin
        (asserts! (is-none (map-get? data-objects { object-id: object-id })) err-point-exists)
        (map-set data-objects { object-id: object-id }
            { creator: tx-sender, points: points, metadata: metadata }
        )
        (ok true)
    )
)

(define-public (authorize-manager (manager-id principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-owner)
        (map-set data-managers { manager-id: manager-id }
            { authorized: true, objects: (list) }
        )
        (ok true)
    )
)

(define-public (revoke-manager (manager-id principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-owner)
        (map-delete data-managers { manager-id: manager-id })
        (ok true)
    )
)

(define-public (update-data-point (point-id (buff 32)) (data (buff 1024)))
    (let
        (
            (point-data (unwrap! (map-get? data-points point-id) err-not-found))
        )
        (asserts! (is-eq tx-sender (get owner point-data)) err-not-owner)
        (map-set data-points point-id
            { owner: tx-sender, data: data, timestamp: stacks-block-time }
        )
        (ok true)
    )
)
