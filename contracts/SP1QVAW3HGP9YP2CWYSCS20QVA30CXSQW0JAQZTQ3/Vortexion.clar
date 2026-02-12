;; title: Vortexion
;; version:
;; summary:
;; description:

;; traits
;;


;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u2142))
(define-constant ERR-NOT-FOUND (err u2143))
(define-constant ERR-INVALID-INPUT (err u2144))
(define-constant ERR-ALREADY-EXISTS (err u2145))

;; Data variables
(define-data-var entity-count uint u0)
(define-data-var is-paused bool false)

;; Data maps
(define-map entities
    { entity-id: uint }
    {
        creator: principal,
        created-at: uint,                   ;; Clarity 4: Unix timestamp
        last-updated: uint,                 ;; Clarity 4: Unix timestamp
        active: bool,
        metadata: (string-utf8 256)
    }
)

(define-map user-entities
    { user: principal, entity-id: uint }
    {
        associated-at: uint,                ;; Clarity 4: Unix timestamp
        role: (string-ascii 20),
        permissions: uint
    }
)

(define-map entity-stats
    { entity-id: uint }
    {
        total-interactions: uint,
        total-value: uint,
        last-activity: uint                 ;; Clarity 4: Unix timestamp
    }
)

;; Read-only functions
(define-read-only (get-entity (entity-id uint))
    (ok (map-get? entities { entity-id: entity-id }))
)

(define-read-only (get-entity-count)
    (ok (var-get entity-count))
)

(define-read-only (get-user-entity (user principal) (entity-id uint))
    (ok (map-get? user-entities { user: user, entity-id: entity-id }))
)

(define-read-only (get-entity-stats (entity-id uint))
    (ok (map-get? entity-stats { entity-id: entity-id }))
)

(define-read-only (is-contract-paused)
    (ok (var-get is-paused))
)

;; Public functions
(define-public (create-entity (metadata (string-utf8 256)))
    (begin
        (asserts! (not (var-get is-paused)) ERR-NOT-AUTHORIZED)

        (let
            (
                (entity-id (var-get entity-count))
            )
            (map-set entities
                { entity-id: entity-id }
                {
                    creator: tx-sender,
                    created-at: stacks-block-time,
                    last-updated: stacks-block-time,
                    active: true,
                    metadata: metadata
                }
            )

            (map-set user-entities
                { user: tx-sender, entity-id: entity-id }
                {
                    associated-at: stacks-block-time,
                    role: "creator",
                    permissions: u255
                }
            )

            (map-set entity-stats
                { entity-id: entity-id }
                {
                    total-interactions: u0,
                    total-value: u0,
                    last-activity: stacks-block-time
                }
            )

            (var-set entity-count (+ entity-id u1))

            (print {
                event: "entity-created",
                entity-id: entity-id,
                creator: tx-sender,
                timestamp: stacks-block-time
            })
            (ok entity-id)
        )
    )
)

(define-public (update-entity (entity-id uint) (metadata (string-utf8 256)))
    (let
        (
            (entity (unwrap! (map-get? entities { entity-id: entity-id }) ERR-NOT-FOUND))
        )
        (asserts! (is-eq (get creator entity) tx-sender) ERR-NOT-AUTHORIZED)

        (map-set entities
            { entity-id: entity-id }
            (merge entity {
                last-updated: stacks-block-time,
                metadata: metadata
            })
        )

        (print {
            event: "entity-updated",
            entity-id: entity-id,
            timestamp: stacks-block-time
        })
        (ok true)
    )
)

(define-public (interact-with-entity (entity-id uint) (value uint))
    (let
        (
            (entity (unwrap! (map-get? entities { entity-id: entity-id }) ERR-NOT-FOUND))
            (stats (default-to
                { total-interactions: u0, total-value: u0, last-activity: u0 }
                (map-get? entity-stats { entity-id: entity-id })
            ))
        )
        (asserts! (get active entity) ERR-NOT-AUTHORIZED)

        (map-set entity-stats
            { entity-id: entity-id }
            {
                total-interactions: (+ (get total-interactions stats) u1),
                total-value: (+ (get total-value stats) value),
                last-activity: stacks-block-time
            }
        )

        (print {
            event: "entity-interaction",
            entity-id: entity-id,
            user: tx-sender,
            value: value,
            timestamp: stacks-block-time
        })
        (ok true)
    )
)

(define-public (toggle-entity-status (entity-id uint))
    (let
        (
            (entity (unwrap! (map-get? entities { entity-id: entity-id }) ERR-NOT-FOUND))
        )
        (asserts! (is-eq (get creator entity) tx-sender) ERR-NOT-AUTHORIZED)

        (map-set entities
            { entity-id: entity-id }
            (merge entity { active: (not (get active entity)) })
        )
        (ok true)
    )
)

(define-public (pause-contract)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set is-paused true)
        (ok true)
    )
)

(define-public (unpause-contract)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set is-paused false)
        (ok true)
    )
)
