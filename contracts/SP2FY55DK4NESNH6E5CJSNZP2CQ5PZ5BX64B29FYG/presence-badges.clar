
(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; ============================================
;; CONSTANTS
;; ============================================

(define-constant CONTRACT_OWNER tx-sender)

;; Error codes
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_NOT_TOKEN_OWNER (err u101))
(define-constant ERR_TOKEN_NOT_FOUND (err u102))
(define-constant ERR_INVALID_BADGE_TYPE (err u103))

;; Badge type IDs
(define-constant BADGE_WEEK_WARRIOR u1)      ;; 7-day streak
(define-constant BADGE_MONTHLY_MASTER u2)    ;; 30-day streak
(define-constant BADGE_CENTURY_CLUB u3)      ;; 100-day streak
(define-constant BADGE_CHATTERBOX u4)        ;; 100 comments
(define-constant BADGE_LOVE_MACHINE u5)      ;; 500 likes
(define-constant BADGE_OG_PRESENCE u6)       ;; 100 check-ins

;; Base URI for metadata (can be updated by owner)
;; Using 210 max length to allow room for badge-type suffix (int-to-ascii returns up to 40 chars)
(define-data-var base-uri (string-ascii 210) "https://presence-protocol.app/metadata/")

;; ============================================
;; NFT DEFINITION
;; ============================================

(define-non-fungible-token presence-badge uint)

;; ============================================
;; DATA STORAGE
;; ============================================

;; Track last token ID
(define-data-var last-token-id uint u0)

;; Map token ID to badge type
(define-map token-badge-type uint uint)

;; Map token ID to minted timestamp (block height)
(define-map token-mint-time uint uint)

;; Authorized minter (presence-tracker contract)
(define-data-var authorized-minter principal CONTRACT_OWNER)

;; ============================================
;; AUTHORIZATION
;; ============================================

;; Set the authorized minter (only presence-tracker contract should mint)
(define-public (set-authorized-minter (new-minter principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set authorized-minter new-minter)
    (ok true)
  )
)

;; ============================================
;; SIP-009 REQUIRED FUNCTIONS
;; ============================================

;; Get last token ID
(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

;; Get token URI - returns metadata URL for the badge
(define-read-only (get-token-uri (token-id uint))
  (let
    (
      (badge-type (default-to u0 (map-get? token-badge-type token-id)))
    )
    (ok (some (concat (var-get base-uri) (int-to-ascii (to-int badge-type)))))
  )
)

;; Get owner of token
(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? presence-badge token-id))
)

;; Transfer token
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_NOT_TOKEN_OWNER)
    (asserts! (is-some (nft-get-owner? presence-badge token-id)) ERR_TOKEN_NOT_FOUND)
    (nft-transfer? presence-badge token-id sender recipient)
  )
)

;; ============================================
;; MINTING FUNCTIONS
;; ============================================

;; Mint a new badge (only callable by authorized minter or owner)
(define-public (mint (recipient principal) (badge-type uint))
  (let
    (
      (token-id (+ (var-get last-token-id) u1))
    )
    ;; Check authorization
    (asserts!
      (or
        (is-eq contract-caller (var-get authorized-minter))
        (is-eq contract-caller CONTRACT_OWNER)
      )
      ERR_NOT_AUTHORIZED
    )
    ;; Validate badge type (1-6)
    (asserts! (and (>= badge-type u1) (<= badge-type u6)) ERR_INVALID_BADGE_TYPE)
    ;; Mint the NFT
    (try! (nft-mint? presence-badge token-id recipient))
    ;; Store badge metadata
    (map-set token-badge-type token-id badge-type)
    (map-set token-mint-time token-id stacks-block-height)
    ;; Update last token ID
    (var-set last-token-id token-id)
    ;; Emit event
    (print {
      event: "badge-minted",
      token-id: token-id,
      badge-type: badge-type,
      recipient: recipient,
      block-height: stacks-block-height
    })
    (ok token-id)
  )
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

;; Get badge type for a token
(define-read-only (get-badge-type (token-id uint))
  (map-get? token-badge-type token-id)
)

;; Get mint time for a token
(define-read-only (get-mint-time (token-id uint))
  (map-get? token-mint-time token-id)
)

;; Get badge name by type
(define-read-only (get-badge-name (badge-type uint))
  (if (is-eq badge-type BADGE_WEEK_WARRIOR)
    (ok "Week Warrior")
    (if (is-eq badge-type BADGE_MONTHLY_MASTER)
      (ok "Monthly Master")
      (if (is-eq badge-type BADGE_CENTURY_CLUB)
        (ok "Century Club")
        (if (is-eq badge-type BADGE_CHATTERBOX)
          (ok "Chatterbox")
          (if (is-eq badge-type BADGE_LOVE_MACHINE)
            (ok "Love Machine")
            (if (is-eq badge-type BADGE_OG_PRESENCE)
              (ok "OG Presence")
              ERR_INVALID_BADGE_TYPE
            )
          )
        )
      )
    )
  )
)

;; Get authorized minter
(define-read-only (get-authorized-minter)
  (var-get authorized-minter)
)

;; ============================================
;; ADMIN FUNCTIONS
;; ============================================

;; Update base URI (only owner)
(define-public (set-base-uri (new-uri (string-ascii 210)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set base-uri new-uri)
    ;; Emit SIP-019 metadata update notification
    (print {
      notification: "token-metadata-update",
      payload: {
        contract-id: (as-contract tx-sender),
        token-class: "nft"
      }
    })
    (ok true)
  )
)

