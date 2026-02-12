;; Reputation Badges Contract (SIP-009 NFT)
;; Achievement tracking with non-transferable badges
;; Built with Clarity 4 features for Stacks Builder Challenge

;; ============================================
;; TRAITS - Define SIP-009 locally
;; ============================================

(define-trait nft-trait
  (
    (get-last-token-id () (response uint uint))
    (get-token-uri (uint) (response (optional (string-ascii 256)) uint))
    (get-owner (uint) (response (optional principal) uint))
    (transfer (uint principal principal) (response bool uint))
  )
)

;; ============================================
;; CONSTANTS & ERRORS  
;; ============================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-NOT-FOUND (err u401))
(define-constant ERR-ALREADY-MINTED (err u402))
(define-constant ERR-BADGE-NOT-EARNED (err u403))
(define-constant ERR-TRANSFER-BLOCKED (err u404))
(define-constant ERR-INVALID-BADGE-TYPE (err u405))
(define-constant ERR-REQUIREMENTS-NOT-MET (err u406))

;; Badge Types
(define-constant BADGE-EARLY-ADOPTER u1)
(define-constant BADGE-POWER-USER u2)
(define-constant BADGE-ALERT-MASTER u3)
(define-constant BADGE-WHALE-WATCHER u4)
(define-constant BADGE-STAKER u5)
(define-constant BADGE-REFERRER u6)
(define-constant BADGE-CONTRIBUTOR u7)
(define-constant BADGE-LEGENDARY u8)

;; ============================================
;; NFT DEFINITION
;; ============================================

(define-non-fungible-token stackpulse-badge uint)

;; ============================================
;; DATA VARIABLES
;; ============================================

(define-data-var token-id-nonce uint u0)
(define-data-var base-uri (string-ascii 256) "https://stackpulse.io/badges/metadata/")

;; ============================================
;; DATA MAPS
;; ============================================

;; Badge metadata
(define-map badge-metadata
  uint  ;; token-id
  {
    badge-type: uint,
    recipient: principal,
    minted-at: uint,
    achievement: (string-utf8 128),
    rarity: (string-ascii 16)
  }
)

;; Track which badges a user has
(define-map user-badges
  { user: principal, badge-type: uint }
  uint  ;; token-id
)

;; Badge type definitions
(define-map badge-definitions
  uint  ;; badge-type
  {
    name: (string-ascii 32),
    description: (string-utf8 256),
    rarity: (string-ascii 16),
    max-supply: uint,
    minted-count: uint,
    is-soulbound: bool
  }
)

;; Achievement requirements
(define-map badge-requirements
  uint  ;; badge-type
  {
    min-alerts: uint,
    min-triggered: uint,
    min-staked: uint,
    min-referrals: uint,
    min-subscription-tier: uint
  }
)

;; ============================================
;; INITIALIZATION - Badge Definitions
;; ============================================

;; Early Adopter - First 1000 users
(map-set badge-definitions BADGE-EARLY-ADOPTER
  { name: "Early Adopter", description: u"One of the first 1000 StackPulse users", 
    rarity: "rare", max-supply: u1000, minted-count: u0, is-soulbound: true })
(map-set badge-requirements BADGE-EARLY-ADOPTER
  { min-alerts: u0, min-triggered: u0, min-staked: u0, min-referrals: u0, min-subscription-tier: u0 })

;; Power User - Created 25+ alerts
(map-set badge-definitions BADGE-POWER-USER
  { name: "Power User", description: u"Created 25 or more alerts on StackPulse", 
    rarity: "uncommon", max-supply: u10000, minted-count: u0, is-soulbound: true })
(map-set badge-requirements BADGE-POWER-USER
  { min-alerts: u25, min-triggered: u0, min-staked: u0, min-referrals: u0, min-subscription-tier: u1 })

;; Alert Master - 100+ alerts triggered
(map-set badge-definitions BADGE-ALERT-MASTER
  { name: "Alert Master", description: u"Had 100 or more alerts triggered", 
    rarity: "rare", max-supply: u5000, minted-count: u0, is-soulbound: true })
(map-set badge-requirements BADGE-ALERT-MASTER
  { min-alerts: u10, min-triggered: u100, min-staked: u0, min-referrals: u0, min-subscription-tier: u1 })

;; Whale Watcher - Tracking 1M+ STX threshold
(map-set badge-definitions BADGE-WHALE-WATCHER
  { name: "Whale Watcher", description: u"Created whale alert with 1M+ STX threshold", 
    rarity: "epic", max-supply: u1000, minted-count: u0, is-soulbound: true })
(map-set badge-requirements BADGE-WHALE-WATCHER
  { min-alerts: u1, min-triggered: u0, min-staked: u0, min-referrals: u0, min-subscription-tier: u2 })

;; Staker - Staked 100+ STX
(map-set badge-definitions BADGE-STAKER
  { name: "Staker", description: u"Staked 100 or more STX in the fee vault", 
    rarity: "common", max-supply: u50000, minted-count: u0, is-soulbound: true })
(map-set badge-requirements BADGE-STAKER
  { min-alerts: u0, min-triggered: u0, min-staked: u100000000, min-referrals: u0, min-subscription-tier: u0 })

;; Referrer - Referred 10+ users
(map-set badge-definitions BADGE-REFERRER
  { name: "Top Referrer", description: u"Referred 10 or more users to StackPulse", 
    rarity: "uncommon", max-supply: u10000, minted-count: u0, is-soulbound: true })
(map-set badge-requirements BADGE-REFERRER
  { min-alerts: u0, min-triggered: u0, min-staked: u0, min-referrals: u10, min-subscription-tier: u0 })

;; Contributor - GitHub contributor
(map-set badge-definitions BADGE-CONTRIBUTOR
  { name: "Contributor", description: u"Contributed to StackPulse development", 
    rarity: "epic", max-supply: u100, minted-count: u0, is-soulbound: true })
(map-set badge-requirements BADGE-CONTRIBUTOR
  { min-alerts: u0, min-triggered: u0, min-staked: u0, min-referrals: u0, min-subscription-tier: u0 })

;; Legendary - All achievements unlocked
(map-set badge-definitions BADGE-LEGENDARY
  { name: "Legendary", description: u"Unlocked all StackPulse achievements", 
    rarity: "legendary", max-supply: u50, minted-count: u0, is-soulbound: true })
(map-set badge-requirements BADGE-LEGENDARY
  { min-alerts: u50, min-triggered: u500, min-staked: u500000000, min-referrals: u25, min-subscription-tier: u3 })

;; ============================================
;; SIP-009 FUNCTIONS
;; ============================================

(define-read-only (get-last-token-id)
  (ok (var-get token-id-nonce))
)

(define-read-only (get-token-uri (token-id uint))
  (let
    (
      (metadata (map-get? badge-metadata token-id))
    )
    (match metadata
      meta (ok (some (concat (var-get base-uri) (uint-to-char token-id))))
      (ok none)
    )
  )
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? stackpulse-badge token-id))
)

;; Transfer - BLOCKED for soulbound badges
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (let
    (
      (metadata (unwrap! (map-get? badge-metadata token-id) ERR-NOT-FOUND))
      (badge-def (unwrap! (map-get? badge-definitions (get badge-type metadata)) ERR-NOT-FOUND))
    )
    ;; Block transfer if soulbound
    (asserts! (not (get is-soulbound badge-def)) ERR-TRANSFER-BLOCKED)
    (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
    
    (nft-transfer? stackpulse-badge token-id sender recipient)
  )
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

;; Get badge metadata
(define-read-only (get-badge-metadata (token-id uint))
  (map-get? badge-metadata token-id)
)

;; Get badge definition
(define-read-only (get-badge-definition (badge-type uint))
  (map-get? badge-definitions badge-type)
)

;; Get badge requirements
(define-read-only (get-badge-requirements (badge-type uint))
  (map-get? badge-requirements badge-type)
)

;; Check if user has badge
(define-read-only (has-badge (user principal) (badge-type uint))
  (is-some (map-get? user-badges { user: user, badge-type: badge-type }))
)

;; Get user's badge token ID for a type
(define-read-only (get-user-badge (user principal) (badge-type uint))
  (map-get? user-badges { user: user, badge-type: badge-type })
)

;; Check if badge type is valid
(define-read-only (is-valid-badge-type (badge-type uint))
  (and (>= badge-type u1) (<= badge-type u8))
)

;; Get total badges minted for a type
(define-read-only (get-badge-supply (badge-type uint))
  (match (map-get? badge-definitions badge-type)
    def (get minted-count def)
    u0
  )
)

;; Get all badge types
(define-read-only (get-badge-types)
  (list 
    BADGE-EARLY-ADOPTER
    BADGE-POWER-USER
    BADGE-ALERT-MASTER
    BADGE-WHALE-WATCHER
    BADGE-STAKER
    BADGE-REFERRER
    BADGE-CONTRIBUTOR
    BADGE-LEGENDARY
  )
)

;; ============================================
;; HELPER FUNCTIONS
;; ============================================

;; Convert uint to ASCII character (for single digits)
(define-read-only (uint-to-char (value uint))
  (if (<= value u9)
    (unwrap-panic (element-at "0123456789" value))
    "0"
  )
)

;; ============================================
;; PUBLIC FUNCTIONS
;; ============================================

;; Mint badge (admin or verified)
(define-public (mint-badge (recipient principal) (badge-type uint) (achievement (string-utf8 128)))
  (let
    (
      (token-id (+ (var-get token-id-nonce) u1))
      (badge-def (unwrap! (map-get? badge-definitions badge-type) ERR-INVALID-BADGE-TYPE))
    )
    ;; Only admin can mint
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    ;; Check not already minted for this user
    (asserts! (is-none (map-get? user-badges { user: recipient, badge-type: badge-type })) ERR-ALREADY-MINTED)
    
    ;; Check supply limit
    (asserts! (< (get minted-count badge-def) (get max-supply badge-def)) ERR-REQUIREMENTS-NOT-MET)
    
    ;; Mint NFT
    (try! (nft-mint? stackpulse-badge token-id recipient))
    
    ;; Store metadata
    (map-set badge-metadata token-id
      {
        badge-type: badge-type,
        recipient: recipient,
        minted-at: stacks-block-height,
        achievement: achievement,
        rarity: (get rarity badge-def)
      }
    )
    
    ;; Update user badges map
    (map-set user-badges { user: recipient, badge-type: badge-type } token-id)
    
    ;; Update minted count
    (map-set badge-definitions badge-type
      (merge badge-def {
        minted-count: (+ (get minted-count badge-def) u1)
      })
    )
    
    ;; Update nonce
    (var-set token-id-nonce token-id)
    
    ;; Emit event for chainhook
    (print {
      event: "badge-minted",
      token-id: token-id,
      recipient: recipient,
      badge-type: badge-type,
      badge-name: (get name badge-def),
      rarity: (get rarity badge-def),
      achievement: achievement,
      block: stacks-block-height
    })
    
    (ok token-id)
  )
)

;; Claim badge (user claims if eligible)
(define-public (claim-badge (badge-type uint))
  (let
    (
      (caller tx-sender)
      (token-id (+ (var-get token-id-nonce) u1))
      (badge-def (unwrap! (map-get? badge-definitions badge-type) ERR-INVALID-BADGE-TYPE))
      (requirements (unwrap! (map-get? badge-requirements badge-type) ERR-INVALID-BADGE-TYPE))
      (user-data (unwrap! (contract-call? .stackpulse-registry get-user caller) ERR-REQUIREMENTS-NOT-MET))
    )
    ;; Check not already claimed
    (asserts! (is-none (map-get? user-badges { user: caller, badge-type: badge-type })) ERR-ALREADY-MINTED)
    
    ;; Check supply limit
    (asserts! (< (get minted-count badge-def) (get max-supply badge-def)) ERR-REQUIREMENTS-NOT-MET)
    
    ;; Check requirements
    (asserts! (>= (get alerts-created user-data) (get min-alerts requirements)) ERR-REQUIREMENTS-NOT-MET)
    (asserts! (>= (get alerts-triggered user-data) (get min-triggered requirements)) ERR-REQUIREMENTS-NOT-MET)
    (asserts! (>= (get tier user-data) (get min-subscription-tier requirements)) ERR-REQUIREMENTS-NOT-MET)
    
    ;; Mint NFT
    (try! (nft-mint? stackpulse-badge token-id caller))
    
    ;; Store metadata
    (map-set badge-metadata token-id
      {
        badge-type: badge-type,
        recipient: caller,
        minted-at: stacks-block-height,
        achievement: u"Self-claimed achievement badge",
        rarity: (get rarity badge-def)
      }
    )
    
    ;; Update user badges map
    (map-set user-badges { user: caller, badge-type: badge-type } token-id)
    
    ;; Update minted count
    (map-set badge-definitions badge-type
      (merge badge-def {
        minted-count: (+ (get minted-count badge-def) u1)
      })
    )
    
    ;; Update nonce
    (var-set token-id-nonce token-id)
    
    ;; Emit event for chainhook
    (print {
      event: "badge-claimed",
      token-id: token-id,
      recipient: caller,
      badge-type: badge-type,
      badge-name: (get name badge-def),
      rarity: (get rarity badge-def),
      block: stacks-block-height
    })
    
    (ok token-id)
  )
)

;; Update base URI (admin only)
(define-public (set-base-uri (new-uri (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set base-uri new-uri)
    (ok true)
  )
)

;; Burn badge (only owner can burn their own)
(define-public (burn (token-id uint))
  (let
    (
      (owner (unwrap! (nft-get-owner? stackpulse-badge token-id) ERR-NOT-FOUND))
      (metadata (unwrap! (map-get? badge-metadata token-id) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
    
    ;; Burn NFT
    (try! (nft-burn? stackpulse-badge token-id owner))
    
    ;; Remove from user badges
    (map-delete user-badges { user: owner, badge-type: (get badge-type metadata) })
    
    (print {
      event: "badge-burned",
      token-id: token-id,
      owner: owner,
      badge-type: (get badge-type metadata),
      block: stacks-block-height
    })
    
    (ok true)
  )
)
