;; Badge2048 Smart Contract
;; Implements SIP-009 NFT standard for achievement badges
;; Each badge represents a score milestone achievement in the 2048 game

;; ============================================================================
;; SIP-009 NFT Trait (must be implemented)
;; ============================================================================

;; Note: SIP-009 standard functions are implemented directly using Clarity's built-in NFT functions

;; ============================================================================
;; Constants
;; ============================================================================

;; Badge tier score thresholds
(define-constant TIER-BRONZE-THRESHOLD u1024)
(define-constant TIER-SILVER-THRESHOLD u2048)
(define-constant TIER-GOLD-THRESHOLD u4096)
(define-constant TIER-ELITE-THRESHOLD u8192)

;; Error codes
(define-constant ERR-INVALID-TIER u1001)
(define-constant ERR-SCORE-TOO-LOW u1002)
(define-constant ERR-ALREADY-MINTED u1003)
(define-constant ERR-UNAUTHORIZED u1004)
(define-constant ERR-INSUFFICIENT-FUNDS u1005)
(define-constant ERR-NOT-FOUND u1006)

;; ============================================================================
;; Data Variables
;; ============================================================================

;; NFT token definition
(define-non-fungible-token badge-nft uint)

;; Last token ID counter
(define-data-var last-token-id uint u0)

;; ============================================================================
;; Data Maps
;; ============================================================================

;; Player high score tracking
(define-map player-high-score
  principal
  uint)

;; Badge ownership tracking (owner + tier -> token-id)
(define-map badge-ownership
  {owner: principal, tier: (string-ascii 10)}
  uint)

;; Badge metadata (token-id -> metadata)
(define-map badge-metadata
  uint
  {
    tier: (string-ascii 10),
    threshold: uint,
    score: uint,
    minted-at: uint
  })

;; Badge minted count per tier (for statistics)
(define-map badge-mint-count
  (string-ascii 10)
  uint)

;; ============================================================================
;; Helper Functions
;; ============================================================================

;; Get threshold for a tier
(define-read-only (get-tier-threshold (tier (string-ascii 10)))
  (ok
    (if (is-eq tier "bronze")
      TIER-BRONZE-THRESHOLD
      (if (is-eq tier "silver")
        TIER-SILVER-THRESHOLD
        (if (is-eq tier "gold")
          TIER-GOLD-THRESHOLD
          (if (is-eq tier "elite")
            TIER-ELITE-THRESHOLD
            u0
          )
        )
      )
    )
  )
)

;; Check if tier is valid
(define-read-only (is-valid-tier (tier (string-ascii 10)))
  (or
    (is-eq tier "bronze")
    (or
      (is-eq tier "silver")
      (or
        (is-eq tier "gold")
        (is-eq tier "elite")
      )
    )
  )
)

;; Increment mint count for a tier
(define-private (increment-mint-count (tier (string-ascii 10)))
  (let ((current-count (default-to u0 (map-get? badge-mint-count tier))))
    (map-set badge-mint-count tier (+ current-count u1))
  )
)

;; ============================================================================
;; SIP-009 NFT Trait Implementation
;; ============================================================================

;; Get last token ID
(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

;; Get token URI (metadata URI - can be extended later with IPFS)
;; Note: Clarity doesn't have to-string, so we return a base URI
;; The token ID can be appended by the frontend or indexer
;; Parameter token-id is kept for SIP-009 compatibility but not used in URI
(define-read-only (get-token-uri (token-id uint))
  (ok (some "https://badge2048.com/metadata/"))
)

;; Get owner of a token
(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? badge-nft token-id))
)

;; Transfer token
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq sender tx-sender) (err ERR-UNAUTHORIZED))
    (nft-transfer? badge-nft token-id sender recipient)
  )
)

;; ============================================================================
;; Public Functions
;; ============================================================================

;; Mint a badge NFT
(define-public (mint-badge (tier (string-ascii 10)) (score uint))
  (let (
    (caller tx-sender)
    (threshold (unwrap! (get-tier-threshold tier) (err ERR-INVALID-TIER)))
    (new-token-id (+ (var-get last-token-id) u1))
  )
    (begin
      ;; Validate tier
      (asserts! (is-valid-tier tier) (err ERR-INVALID-TIER))
      
      ;; Validate score meets threshold
      (asserts! (>= score threshold) (err ERR-SCORE-TOO-LOW))
      
      ;; Check if badge already minted for this owner+tier
      (asserts! (is-none (map-get? badge-ownership {owner: caller, tier: tier})) (err ERR-ALREADY-MINTED))
      
      ;; Mint the NFT
      (try! (nft-mint? badge-nft new-token-id caller))
      
      ;; Update last token ID
      (var-set last-token-id new-token-id)
      
      ;; Store badge metadata
      ;; Note: block-height is not directly usable in tuple, using u0 as placeholder
      ;; Can be updated later or retrieved from transaction receipt
      (map-set badge-metadata new-token-id {
        tier: tier,
        threshold: threshold,
        score: score,
        minted-at: u0
      })
      
      ;; Update ownership map
      (map-set badge-ownership {owner: caller, tier: tier} new-token-id)
      
      ;; Increment mint count for this tier
      (increment-mint-count tier)
      
      ;; Update high score if this score is higher
      (let ((current-high-score (default-to u0 (map-get? player-high-score caller))))
        (if (> score current-high-score)
          (map-set player-high-score caller score)
          true
        )
      )
      
      ;; Emit badge-minted event
      ;; Event structure: {event: "badge-minted", player: principal, tier: string, token-id: uint, score: uint}
      (print {
        event: "badge-minted",
        player: caller,
        tier: tier,
        token-id: new-token-id,
        score: score
      })
      
      ;; Return token ID
      (ok new-token-id)
    )
  )
)

;; Update high score
(define-public (update-high-score (score uint))
  (let (
    (caller tx-sender)
    (current-high-score (default-to u0 (map-get? player-high-score caller)))
  )
    (begin
      (if (> score current-high-score)
        (begin
          (map-set player-high-score caller score)
          
          ;; Emit high-score-updated event
          ;; Event structure: {event: "high-score-updated", player: principal, old-score: uint, new-score: uint}
          (print {
            event: "high-score-updated",
            player: caller,
            old-score: current-high-score,
            new-score: score
          })
          
          (ok true)
        )
        (ok false)
      )
    )
  )
)

;; ============================================================================
;; Read-Only Functions
;; ============================================================================

;; Get player's high score
(define-read-only (get-high-score (player principal))
  (ok (default-to u0 (map-get? player-high-score player)))
)

;; Get badge ownership (returns token-id if owned)
(define-read-only (get-badge-ownership (player principal) (tier (string-ascii 10)))
  (ok (map-get? badge-ownership {owner: player, tier: tier}))
)

;; Get badge metadata
(define-read-only (get-badge-metadata (token-id uint))
  (ok (map-get? badge-metadata token-id))
)

;; Get mint count for a tier
(define-read-only (get-badge-mint-count (tier (string-ascii 10)))
  (ok (default-to u0 (map-get? badge-mint-count tier)))
)

;; ============================================================================
;; Events
;; ============================================================================

;; Events are emitted using print statements in Clarity
;; Events will appear in transaction receipts and can be queried via Stacks API
;; Indexers (like Hiro API, talent.app) can index these events for frontend display

;; Event: badge-minted
;; Emitted when a badge NFT is successfully minted
;; Structure: {event: "badge-minted", player: principal, tier: string-ascii, token-id: uint, score: uint}
;; Example: {event: "badge-minted", player: ST..., tier: "bronze", token-id: u1, score: u1024}

;; Event: high-score-updated
;; Emitted when a player's high score is updated
;; Structure: {event: "high-score-updated", player: principal, old-score: uint, new-score: uint}
;; Example: {event: "high-score-updated", player: ST..., old-score: u1000, new-score: u2000}

;; Note: block-height is not included in events as it's automatically available in transaction receipts
;; Frontend can query transaction receipt to get block-height and timestamp
