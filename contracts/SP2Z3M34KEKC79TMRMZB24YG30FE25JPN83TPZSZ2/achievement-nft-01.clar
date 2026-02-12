;; ACHIEVEMENT NFT CONTRACT (SIP-009)
;; Mintable achievement badges for player accomplishments

;; Define trait locally for devnet testing
(define-trait nft-trait
  (
    (get-last-token-id () (response uint uint))
    (get-token-uri (uint) (response (optional (string-ascii 256)) uint))
    (get-owner (uint) (response (optional principal) uint))
    (transfer (uint principal principal) (response bool uint))
  )
)

;; impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait
;; Commented for local testing - uncomment for mainnet deployment

;; ============================================================================
;; CONSTANTS
;; ============================================================================

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u600))
(define-constant ERR_NOT_FOUND (err u601))
(define-constant ERR_ALREADY_MINTED (err u602))

;; Achievement IDs
(define-constant ACHIEVEMENT_FIRST_BLOOD u1)
(define-constant ACHIEVEMENT_BEGINNER_MASTER u2)
(define-constant ACHIEVEMENT_INTERMEDIATE_MASTER u3)
(define-constant ACHIEVEMENT_EXPERT_MASTER u4)
(define-constant ACHIEVEMENT_SPEED_DEMON u5)
(define-constant ACHIEVEMENT_LIGHTNING_FAST u6)
(define-constant ACHIEVEMENT_EXPERT_SPEEDRUN u7)
(define-constant ACHIEVEMENT_PERFECT_GAME u8)
(define-constant ACHIEVEMENT_FLAG_MASTER u9)
(define-constant ACHIEVEMENT_STREAK_KING u10)
(define-constant ACHIEVEMENT_CENTURY_CLUB u11)
(define-constant ACHIEVEMENT_WORLD_RECORD u12)
(define-constant ACHIEVEMENT_TOURNAMENT_VICTOR u13)
(define-constant ACHIEVEMENT_HIGH_ROLLER u14)
(define-constant ACHIEVEMENT_DAILY_GRINDER u15)

;; ============================================================================
;; DATA VARS
;; ============================================================================

(define-data-var last-token-id uint u0)

;; ============================================================================
;; DATA MAPS
;; ============================================================================

;; NFT ownership
(define-map token-owners
  { token-id: uint }
  { owner: principal }
)

;; Player achievements (which achievements player has)
(define-map player-achievements
  { player: principal, achievement-id: uint }
  {
    token-id: uint,
    earned-at: uint,
    game-id: (optional uint)
  }
)

;; Achievement metadata
(define-map achievement-metadata
  { achievement-id: uint }
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    rarity: (string-ascii 20),
    category: (string-ascii 20),
    image-uri: (string-ascii 256)
  }
)

;; ============================================================================
;; SIP-009 IMPLEMENTATION
;; ============================================================================

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
  (ok (some "ipfs://QmAchievementMetadata/{id}"))
)

(define-read-only (get-owner (token-id uint))
  (ok (get owner (map-get? token-owners {token-id: token-id})))
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  ;; Achievements are soulbound - cannot transfer
  ERR_NOT_AUTHORIZED
)

;; ============================================================================
;; ACHIEVEMENT AWARDING
;; ============================================================================

;; Award achievement to player
(define-public (award-achievement (player principal) (achievement-id uint))
  (let
    (
      (existing (map-get? player-achievements {player: player, achievement-id: achievement-id}))
      (new-token-id (+ (var-get last-token-id) u1))
    )
    ;; Check if already has achievement
    (asserts! (is-none existing) ERR_ALREADY_MINTED)
    
    ;; Mint NFT
    (map-set token-owners
      {token-id: new-token-id}
      {owner: player}
    )
    
    ;; Record achievement
    (map-set player-achievements
      {player: player, achievement-id: achievement-id}
      {
        token-id: new-token-id,
        earned-at: stacks-block-height,
        game-id: none
      }
    )
    
    ;; Increment token ID
    (var-set last-token-id new-token-id)
    
    ;; Award achievement bonus via economy contract
    (unwrap! (contract-call? .economy-01 award-achievement-bonus player achievement-id) ERR_NOT_AUTHORIZED)
    
    (ok new-token-id)
  )
)

;; Check and award achievements based on player stats
(define-public (check-achievements (player principal) (game-id uint))
  (let
    (
      ;; Get player statistics
      (stats (unwrap! (contract-call? .player-profile-01 get-player-stats player) ERR_NOT_FOUND))
      ;; Get player streaks information
      (streaks (unwrap! (contract-call? .player-profile-01 get-player-streaks player) ERR_NOT_FOUND))
      ;; Get game information
      (game (unwrap! (contract-call? .game-core-01 get-game-info game-id) ERR_NOT_FOUND))
    )
    ;; Check First Blood
    (begin
      (if (is-eq (default-to u0 (get total-wins stats)) u1)
        (try! (award-achievement player ACHIEVEMENT_FIRST_BLOOD))
        u0
      )
    )
    
    ;; Check Master achievements
    (begin
      (if (is-eq (default-to u0 (get beginner-wins stats)) u10)
        (try! (award-achievement player ACHIEVEMENT_BEGINNER_MASTER))
        u0
      )
    )
    (begin
      (if (is-eq (default-to u0 (get intermediate-wins stats)) u10)
        (try! (award-achievement player ACHIEVEMENT_INTERMEDIATE_MASTER))
        u0
      )
    )
    (begin
      (if (is-eq (default-to u0 (get expert-wins stats)) u10)
        (try! (award-achievement player ACHIEVEMENT_EXPERT_MASTER))
        u0
      )
    )
    
    ;; Check Century Club
    (begin
      (if (is-eq (default-to u0 (get total-wins stats)) u100)
        (try! (award-achievement player ACHIEVEMENT_CENTURY_CLUB))
        u0
      )
    )
    
    ;; Check Streak King
    (begin
      (if (is-eq (default-to u0 (get current-win-streak streaks)) u10)
        (try! (award-achievement player ACHIEVEMENT_STREAK_KING))
        u0
      )
    )
    
    ;; Check Daily Grinder
    (begin
      (if (is-eq (default-to u0 (get current-login-streak streaks)) u30)
        (try! (award-achievement player ACHIEVEMENT_DAILY_GRINDER))
        u0
      )
    )
    
    (ok true)
  )
)

;; ============================================================================
;; READ-ONLY FUNCTIONS
;; ============================================================================

;; Get player's achievements
(define-read-only (get-player-achievements (player principal))
  ;; In production, would return list of all achievements
  ;; For now, return placeholder
  (ok (list))
)

;; Check if player has achievement
(define-read-only (has-achievement (player principal) (achievement-id uint))
  (is-some (map-get? player-achievements {player: player, achievement-id: achievement-id}))
)

;; Get achievement metadata
(define-read-only (get-achievement-info (achievement-id uint))
  (ok (map-get? achievement-metadata {achievement-id: achievement-id}))
)

;; ============================================================================
;; INITIALIZATION
;; ============================================================================

;; Initialize achievement metadata (called once on deployment)
(define-private (init-metadata)
  (begin
    (map-set achievement-metadata
      {achievement-id: ACHIEVEMENT_FIRST_BLOOD}
      {
        name: "First Blood",
        description: "Win your first game",
        rarity: "Common",
        category: "Milestone",
        image-uri: "ipfs://QmFirstBlood"
      }
    )
    (map-set achievement-metadata
      {achievement-id: ACHIEVEMENT_WORLD_RECORD}
      {
        name: "World Record Holder",
        description: "Set a new world record",
        rarity: "Legendary",
        category: "Elite",
        image-uri: "ipfs://QmWorldRecord"
      }
    )
    ;; Add more metadata...
    true
  )
)
