;; title: TimeVintage
;; version:
;; summary:
;; description:

;; token definitions
(define-non-fungible-token time-nft uint)

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_OWNER_ONLY (err u100))
(define-constant ERR_NOT_TOKEN_OWNER (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_TIME_LOCKED (err u103))
(define-constant ERR_INVALID_UNLOCK_HEIGHT (err u104))
(define-constant ERR_METADATA_FROZEN (err u105))
(define-constant ERR_ALREADY_UNLOCKED (err u106))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u107))
(define-constant ERR_BATCH_LIMIT_EXCEEDED (err u108))
(define-constant MAX_BATCH_SIZE u10)

;; data vars
(define-data-var last-token-id uint u0)
(define-data-var mint-price uint u1000000)
(define-data-var royalty-percentage uint u250)
(define-data-var contract-paused bool false)

;; data maps
(define-map token-metadata
  { token-id: uint }
  {
    name: (string-ascii 256),
    description: (string-ascii 512),
    image: (string-ascii 256),
    unlock-height: uint,
    locked-content: (string-ascii 1024),
    creator: principal,
  }
)

(define-map token-uris
  { token-id: uint }
  { uri: (optional (string-ascii 256)) }
)

(define-map creator-tokens
  { creator: principal }
  { token-ids: (list 1000 uint) }
)

(define-map royalty-recipients
  { token-id: uint }
  {
    recipient: principal,
    percentage: uint,
  }
)

(define-public (transfer
    (token-id uint)
    (sender principal)
    (recipient principal)
  )
  (begin
    (asserts! (is-some (nft-get-owner? time-nft token-id)) ERR_NOT_FOUND)
    (asserts! (is-eq tx-sender sender) ERR_NOT_TOKEN_OWNER)
    (asserts! (is-eq (some sender) (nft-get-owner? time-nft token-id))
      ERR_NOT_TOKEN_OWNER
    )
    (nft-transfer? time-nft token-id sender recipient)
  )
)

(define-public (set-token-uri
    (token-id uint)
    (uri (optional (string-ascii 256)))
  )
  (begin
    (asserts! (is-some (nft-get-owner? time-nft token-id)) ERR_NOT_FOUND)
    (asserts! (is-eq (some tx-sender) (nft-get-owner? time-nft token-id))
      ERR_NOT_TOKEN_OWNER
    )
    (ok (map-set token-uris { token-id: token-id } { uri: uri }))
  )
)

;; read only functions
(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
  (ok (match (map-get? token-uris { token-id: token-id })
    token-uri-data (get uri token-uri-data)
    none
  ))
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? time-nft token-id))
)

(define-read-only (get-token-metadata (token-id uint))
  (map-get? token-metadata { token-id: token-id })
)

(define-read-only (is-unlocked (token-id uint))
  (match (get-token-metadata token-id)
    metadata (>= stacks-block-height (get unlock-height metadata))
    false
  )
)

(define-read-only (get-unlocked-content (token-id uint))
  (let ((metadata (unwrap! (get-token-metadata token-id) (err ERR_NOT_FOUND))))
    (if (>= stacks-block-height (get unlock-height metadata))
      (ok (some (get locked-content metadata)))
      (ok none)
    )
  )
)

(define-read-only (get-unlock-height (token-id uint))
  (match (get-token-metadata token-id)
    metadata (ok (get unlock-height metadata))
    (err ERR_NOT_FOUND)
  )
)

(define-read-only (blocks-until-unlock (token-id uint))
  (match (get-token-metadata token-id)
    metadata (let ((unlock-height (get unlock-height metadata)))
      (if (>= stacks-block-height unlock-height)
        (ok u0)
        (ok (- unlock-height stacks-block-height))
      )
    )
    (err ERR_NOT_FOUND)
  )
)

(define-public (update-unlock-height
    (token-id uint)
    (new-unlock-height uint)
  )
  (let ((metadata (unwrap! (get-token-metadata token-id) ERR_NOT_FOUND)))
    (asserts! (is-eq (some tx-sender) (nft-get-owner? time-nft token-id))
      ERR_NOT_TOKEN_OWNER
    )
    (asserts! (< stacks-block-height (get unlock-height metadata))
      ERR_ALREADY_UNLOCKED
    )
    (asserts! (> new-unlock-height stacks-block-height) ERR_INVALID_UNLOCK_HEIGHT)
    (map-set token-metadata { token-id: token-id }
      (merge metadata { unlock-height: new-unlock-height })
    )
    (ok true)
  )
)

(define-public (burn (token-id uint))
  (begin
    (asserts! (is-eq (some tx-sender) (nft-get-owner? time-nft token-id))
      ERR_NOT_TOKEN_OWNER
    )
    (try! (nft-burn? time-nft token-id tx-sender))
    (map-delete token-metadata { token-id: token-id })
    (map-delete token-uris { token-id: token-id })
    (map-delete royalty-recipients { token-id: token-id })
    (ok true)
  )
)

(define-public (set-royalty
    (token-id uint)
    (recipient principal)
    (percentage uint)
  )
  (begin
    (asserts! (is-eq (some tx-sender) (nft-get-owner? time-nft token-id))
      ERR_NOT_TOKEN_OWNER
    )
    (asserts! (<= percentage u1000) ERR_INVALID_UNLOCK_HEIGHT)
    (ok (map-set royalty-recipients { token-id: token-id } {
      recipient: recipient,
      percentage: percentage,
    }))
  )
)

(define-public (set-mint-price (new-price uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
    (ok (var-set mint-price new-price))
  )
)

(define-public (set-contract-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
    (ok (var-set contract-paused paused))
  )
)

;; additional read-only functions
(define-read-only (get-mint-price)
  (ok (var-get mint-price))
)

(define-read-only (get-royalty-info (token-id uint))
  (map-get? royalty-recipients { token-id: token-id })
)

(define-read-only (get-contract-paused)
  (ok (var-get contract-paused))
)

(define-read-only (get-tokens-by-creator (creator principal))
  (map-get? creator-tokens { creator: creator })
)

(define-read-only (get-total-supply)
  (ok (var-get last-token-id))
)

(define-read-only (token-exists (token-id uint))
  (is-some (nft-get-owner? time-nft token-id))
)

(define-read-only (get-token-info (token-id uint))
  (match (get-token-metadata token-id)
    metadata (ok {
      metadata: metadata,
      owner: (nft-get-owner? time-nft token-id),
      unlocked: (>= stacks-block-height (get unlock-height metadata)),
      blocks-remaining: (if (>= stacks-block-height (get unlock-height metadata))
        u0
        (- (get unlock-height metadata) stacks-block-height)
      ),
    })
    ERR_NOT_FOUND
  )
)
