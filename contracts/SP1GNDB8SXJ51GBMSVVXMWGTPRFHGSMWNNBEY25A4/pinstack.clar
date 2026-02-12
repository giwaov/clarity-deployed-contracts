;; title: pinstack
;; version: 1
;; summary: A decentralized achievement and badge system built on Stacks blockchain.
;; description: Allows administrators to award digital badges for accomplishments, milestones, and achievements. Users can collect badges, showcase their achievements, and verify their credentials on-chain.

;; traits
;;

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_BADGE_TYPE_NOT_FOUND (err u101))
(define-constant ERR_BADGE_ALREADY_OWNED (err u102))
(define-constant ERR_INVALID_BADGE_NAME (err u103))
(define-constant ERR_INVALID_RARITY (err u104))
(define-constant ERR_BADGE_NOT_OWNED (err u105))
(define-constant ERR_UNDERFLOW (err u106))

;; data vars
(define-data-var counter uint u0)
(define-data-var admin principal CONTRACT_OWNER)
(define-data-var next-badge-type-id uint u0)

;; data maps
(define-map badge-types
  uint
  {
    name: (string-utf8 64),
    description: (string-utf8 256),
    rarity: (string-ascii 20),
    image-uri: (string-utf8 256),
    created-at: uint,
    creator: principal
  }
)

(define-map user-badges
  { user: principal, badge-type-id: uint }
  {
    issued-at: uint,
    issuer: principal
  }
)

(define-map user-badge-count principal uint)

;; public functions

;; --- Counter Functions ---

(define-public (increment)
  (let
    ((new-value (+ (var-get counter) u1)))
    (begin
      (var-set counter new-value)
      (print {
        event: "counter-incremented",
        caller: tx-sender,
        new-value: new-value,
        block-height: stacks-block-height
      })
      (ok new-value)
    )
  )
)

(define-public (decrement)
  (let 
    ((current-value (var-get counter)))
    (begin
      ;; Prevent underflow
      (asserts! (> current-value u0) ERR_UNDERFLOW)
      (let
        ((new-value (- current-value u1)))
        (begin
          (var-set counter new-value)
          (print {
            event: "counter-decremented",
            caller: tx-sender,
            new-value: new-value,
            block-height: stacks-block-height
          })
          (ok new-value)
        )
      )
    )
  )
)

;; --- Admin Functions ---

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (var-set admin new-admin)
    (print {
      event: "admin-changed",
      old-admin: tx-sender,
      new-admin: new-admin,
      block-height: stacks-block-height
    })
    (ok true)
  )
)

;; --- Badge Type Functions ---

(define-public (create-badge-type (name (string-utf8 64)) (description (string-utf8 256)) (rarity (string-ascii 20)) (image-uri (string-utf8 256)))
  (let
    (
      (badge-type-id (var-get next-badge-type-id))
    )
    (begin
      (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
      (asserts! (> (len name) u0) ERR_INVALID_BADGE_NAME)
      (asserts! (is-valid-rarity rarity) ERR_INVALID_RARITY)
      
      (map-set badge-types badge-type-id
        {
          name: name,
          description: description,
          rarity: rarity,
          image-uri: image-uri,
          created-at: stacks-block-height,
          creator: tx-sender
        }
      )
      
      (var-set next-badge-type-id (+ badge-type-id u1))
      
      (print {
        event: "badge-type-created",
        badge-type-id: badge-type-id,
        name: name,
        rarity: rarity,
        creator: tx-sender,
        block-height: stacks-block-height
      })
      
      (ok badge-type-id)
    )
  )
)

(define-public (award-badge (badge-type-id uint) (recipient principal))
  (let
    (
      (badge-type (unwrap! (map-get? badge-types badge-type-id) ERR_BADGE_TYPE_NOT_FOUND))
      (current-count (default-to u0 (map-get? user-badge-count recipient)))
    )
    (begin
      (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
      (asserts! (not (has-badge-internal recipient badge-type-id)) ERR_BADGE_ALREADY_OWNED)
      
      (map-set user-badges { user: recipient, badge-type-id: badge-type-id }
        {
          issued-at: stacks-block-height,
          issuer: tx-sender
        }
      )
      
      (map-set user-badge-count recipient (+ current-count u1))
      
      (print {
        event: "badge-awarded",
        badge-type-id: badge-type-id,
        recipient: recipient,
        issuer: tx-sender,
        block-height: stacks-block-height
      })
      
      (ok true)
    )
  )
)

(define-public (revoke-badge (badge-type-id uint) (user principal))
  (let
    (
      (badge (unwrap! (map-get? user-badges { user: user, badge-type-id: badge-type-id }) ERR_BADGE_NOT_OWNED))
      (current-count (default-to u0 (map-get? user-badge-count user)))
    )
    (begin
      (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
      
      (map-delete user-badges { user: user, badge-type-id: badge-type-id })
      
      ;; Safety check to prevent underflow
      (if (> current-count u0)
          (map-set user-badge-count user (- current-count u1))
          (map-set user-badge-count user u0)
      )
      
      (print {
        event: "badge-revoked",
        badge-type-id: badge-type-id,
        user: user,
        revoker: tx-sender,
        block-height: stacks-block-height
      })
      
      (ok true)
    )
  )
)

;; read only functions

(define-read-only (get-counter)
  (ok (var-get counter))
)

(define-read-only (is-admin (user principal))
  (ok (is-eq user (var-get admin)))
)

(define-read-only (get-admin)
  (ok (var-get admin))
)

(define-read-only (get-badge-type (badge-type-id uint))
  (match (map-get? badge-types badge-type-id)
    badge-type (ok badge-type)
    ERR_BADGE_TYPE_NOT_FOUND
  )
)

(define-read-only (has-badge (user principal) (badge-type-id uint))
  (ok (has-badge-internal user badge-type-id))
)

(define-read-only (get-user-badge (user principal) (badge-type-id uint))
  (match (map-get? user-badges { user: user, badge-type-id: badge-type-id })
    badge (ok badge)
    ERR_BADGE_NOT_OWNED
  )
)

(define-read-only (get-badge-count (user principal))
  (ok (default-to u0 (map-get? user-badge-count user)))
)

(define-read-only (get-total-badge-types)
  (ok (var-get next-badge-type-id))
)

;; private functions

(define-private (has-badge-internal (user principal) (badge-type-id uint))
  (is-some (map-get? user-badges { user: user, badge-type-id: badge-type-id }))
)

(define-private (is-valid-rarity (rarity (string-ascii 20)))
  (or
    (is-eq rarity "common")
    (or
      (is-eq rarity "rare")
      (or
        (is-eq rarity "epic")
        (is-eq rarity "legendary")
      )
    )
  )
)
