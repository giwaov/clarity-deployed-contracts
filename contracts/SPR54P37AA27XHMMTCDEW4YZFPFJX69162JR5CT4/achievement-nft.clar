;; PopPredict Achievement NFTs
;; SIP-009 compliant NFT contract for user achievements
;; Version: 1.0.0

;; ============================================
;; TRAITS
;; ============================================

;; Note: Implement SIP-009 trait in production with correct trait reference
;; (impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; ============================================
;; CONSTANTS
;; ============================================

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-NOT-FOUND (err u201))
(define-constant ERR-ALREADY-EXISTS (err u202))
(define-constant ERR-INVALID-ACHIEVEMENT (err u203))
(define-constant ERR-ACHIEVEMENT-LOCKED (err u204))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Achievement types
(define-constant ACHIEVEMENT-FIRST-PREDICTION u1)
(define-constant ACHIEVEMENT-FIRST-WIN u2)
(define-constant ACHIEVEMENT-FIVE-WINS u3)
(define-constant ACHIEVEMENT-TEN-WINS u4)
(define-constant ACHIEVEMENT-HUNDRED-STX-EARNED u5)
(define-constant ACHIEVEMENT-PERFECT-WEEK u6)
(define-constant ACHIEVEMENT-EARLY-ADOPTER u7)
(define-constant ACHIEVEMENT-WHALE u8)
(define-constant ACHIEVEMENT-CONSISTENT-TRADER u9)
(define-constant ACHIEVEMENT-CATEGORY-MASTER u10)

;; ============================================
;; DATA VARIABLES
;; ============================================

(define-data-var token-id-nonce uint u0)
(define-data-var poppredict-contract principal CONTRACT-OWNER)

;; ============================================
;; DATA MAPS
;; ============================================

;; NFT ownership
(define-map token-owners
  { token-id: uint }
  { owner: principal }
)

;; Track which achievements users have earned
(define-map user-achievements
  { user: principal, achievement-type: uint }
  { token-id: uint, earned-at: uint }
)

;; Achievement metadata
(define-map achievement-metadata
  { achievement-type: uint }
  {
    name: (string-ascii 50),
    description: (string-utf8 256),
    image-uri: (string-ascii 256),
    enabled: bool
  }
)

;; User achievement counters
(define-map user-achievement-stats
  { user: principal }
  {
    total-predictions: uint,
    total-wins: uint,
    total-stx-earned: uint,
    achievement-count: uint
  }
)

;; ============================================
;; PRIVATE FUNCTIONS
;; ============================================

(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-poppredict-contract)
  (is-eq contract-caller (var-get poppredict-contract))
)

(define-private (get-user-stats-or-default (user principal))
  (default-to
    { total-predictions: u0, total-wins: u0, total-stx-earned: u0, achievement-count: u0 }
    (map-get? user-achievement-stats { user: user })
  )
)

;; ============================================
;; SIP-009 IMPLEMENTATION
;; ============================================

(define-read-only (get-last-token-id)
  (ok (var-get token-id-nonce))
)

(define-read-only (get-token-uri (token-id uint))
  (match (map-get? token-owners { token-id: token-id })
    owner-data
      (let
        (
          (achievement-type (unwrap! (get-achievement-type-by-token token-id) ERR-NOT-FOUND))
          (metadata (unwrap! (map-get? achievement-metadata { achievement-type: achievement-type }) ERR-NOT-FOUND))
        )
        (ok (some (get image-uri metadata)))
      )
    ERR-NOT-FOUND
  )
)

(define-read-only (get-owner (token-id uint))
  (match (map-get? token-owners { token-id: token-id })
    owner-data (ok (some (get owner owner-data)))
    (ok none)
  )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  ;; Achievement NFTs are soulbound - cannot be transferred
  ERR-ACHIEVEMENT-LOCKED
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

(define-read-only (get-user-achievement (user principal) (achievement-type uint))
  (map-get? user-achievements { user: user, achievement-type: achievement-type })
)

(define-read-only (has-achievement (user principal) (achievement-type uint))
  (is-some (get-user-achievement user achievement-type))
)

(define-read-only (get-achievement-metadata-info (achievement-type uint))
  (map-get? achievement-metadata { achievement-type: achievement-type })
)

(define-read-only (get-user-stats-info (user principal))
  (ok (get-user-stats-or-default user))
)

;; Clarity 4: Get contract verification hash
(define-read-only (get-nft-contract-verification)
  (ok {
    contract-hash: (contract-hash? .achievement-nft),
    current-time: stacks-block-time
  })
)

;; Alternative verification info
(define-read-only (get-nft-contract-info)
  (ok {
    current-time: stacks-block-time,
    total-tokens: (var-get token-id-nonce)
  })
)

(define-read-only (get-achievement-type-by-token (token-id uint))
  (let
    (
      (owner-data (unwrap! (map-get? token-owners { token-id: token-id }) ERR-NOT-FOUND))
      (owner (get owner owner-data))
    )
    ;; Search through user achievements to find matching token-id
    ;; This is a simplified version - in production, consider additional tracking
    (ok ACHIEVEMENT-FIRST-PREDICTION) ;; Placeholder - would need reverse lookup map
  )
)

;; ============================================
;; PUBLIC FUNCTIONS - ADMIN
;; ============================================

(define-public (set-poppredict-contract (new-contract principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (var-set poppredict-contract new-contract))
  )
)

(define-public (set-achievement-metadata
  (achievement-type uint)
  (name (string-ascii 50))
  (description (string-utf8 256))
  (image-uri (string-ascii 256))
  (enabled bool)
)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (map-set achievement-metadata
      { achievement-type: achievement-type }
      {
        name: name,
        description: description,
        image-uri: image-uri,
        enabled: enabled
      }
    ))
  )
)

;; ============================================
;; PUBLIC FUNCTIONS - ACHIEVEMENT MINTING
;; ============================================

(define-public (mint-achievement (user principal) (achievement-type uint))
  (let
    (
      (new-token-id (var-get token-id-nonce))
      (existing-achievement (get-user-achievement user achievement-type))
      (metadata (unwrap! (map-get? achievement-metadata { achievement-type: achievement-type }) ERR-INVALID-ACHIEVEMENT))
      (user-stats (get-user-stats-or-default user))
    )
    (asserts! (or (is-contract-owner) (is-poppredict-contract)) ERR-NOT-AUTHORIZED)
    (asserts! (get enabled metadata) ERR-INVALID-ACHIEVEMENT)
    (asserts! (is-none existing-achievement) ERR-ALREADY-EXISTS)
    
    ;; Mint NFT
    (map-set token-owners
      { token-id: new-token-id }
      { owner: user }
    )
    
    ;; Record achievement
    (map-set user-achievements
      { user: user, achievement-type: achievement-type }
      { token-id: new-token-id, earned-at: stacks-block-height }
    )
    
    ;; Update user stats
    (map-set user-achievement-stats
      { user: user }
      (merge user-stats { achievement-count: (+ (get achievement-count user-stats) u1) })
    )
    
    ;; Increment token ID
    (var-set token-id-nonce (+ new-token-id u1))
    
    ;; Clarity 4: Log achievement mint event (using burn-block-height for Clarity 3 compatibility)
    (print {
      event: "achievement-minted",
      user: user,
      achievement-type: achievement-type,
      token-id: new-token-id,
      burn-block: burn-block-height,  ;; Clarity 4: Replace with stacks-block-time
      block-height: stacks-block-height
    })
    
    (ok new-token-id)
  )
)

;; ============================================
;; PUBLIC FUNCTIONS - STAT TRACKING
;; ============================================

(define-public (increment-predictions (user principal))
  (let
    (
      (stats (get-user-stats-or-default user))
      (new-total (+ (get total-predictions stats) u1))
    )
    (asserts! (or (is-contract-owner) (is-poppredict-contract)) ERR-NOT-AUTHORIZED)
    
    (map-set user-achievement-stats
      { user: user }
      (merge stats { total-predictions: new-total })
    )
    
    ;; Clarity 4: Log prediction increment (using burn-block-height for Clarity 3 compatibility)
    (print {
      event: "prediction-tracked",
      user: user,
      total-predictions: new-total,
      burn-block: burn-block-height  ;; Clarity 4: Replace with stacks-block-time
    })
    
    ;; Auto-mint first prediction achievement
    (if (is-eq new-total u1)
      (mint-achievement user ACHIEVEMENT-FIRST-PREDICTION)
      (ok u0)
    )
  )
)

(define-public (increment-wins (user principal))
  (let
    (
      (stats (get-user-stats-or-default user))
      (new-total (+ (get total-wins stats) u1))
    )
    (asserts! (or (is-contract-owner) (is-poppredict-contract)) ERR-NOT-AUTHORIZED)
    
    (map-set user-achievement-stats
      { user: user }
      (merge stats { total-wins: new-total })
    )
    
    ;; Clarity 4: Log win increment (using burn-block-height for Clarity 3 compatibility)
    (print {
      event: "win-tracked",
      user: user,
      total-wins: new-total,
      burn-block: burn-block-height  ;; Clarity 4: Replace with stacks-block-time
    })
    
    ;; Auto-mint win achievements
    (if (is-eq new-total u1)
      (mint-achievement user ACHIEVEMENT-FIRST-WIN)
      (if (is-eq new-total u5)
        (mint-achievement user ACHIEVEMENT-FIVE-WINS)
        (if (is-eq new-total u10)
          (mint-achievement user ACHIEVEMENT-TEN-WINS)
          (ok u0)
        )
      )
    )
  )
)

(define-public (add-stx-earned (user principal) (amount uint))
  (let
    (
      (stats (get-user-stats-or-default user))
      (new-total (+ (get total-stx-earned stats) amount))
    )
    (asserts! (or (is-contract-owner) (is-poppredict-contract)) ERR-NOT-AUTHORIZED)
    
    (map-set user-achievement-stats
      { user: user }
      (merge stats { total-stx-earned: new-total })
    )
    
    ;; Clarity 4: Log STX earned increment
    (print {
      event: "stx-earned-tracked",
      user: user,
      amount: amount,
      total-earned: new-total,
      timestamp: stacks-block-time
    })
    
    ;; Auto-mint STX earned achievement (100 STX = 100,000,000 microSTX)
    (if (>= new-total u100000000)
      (mint-achievement user ACHIEVEMENT-HUNDRED-STX-EARNED)
      (ok u0)
    )
  )
)

;; ============================================
;; INITIALIZATION
;; ============================================

;; Initialize default achievement metadata
(map-set achievement-metadata
  { achievement-type: ACHIEVEMENT-FIRST-PREDICTION }
  {
    name: "First Prediction",
    description: u"Made your first prediction on PopPredict",
    image-uri: "ipfs://placeholder/first-prediction.png",
    enabled: true
  }
)

(map-set achievement-metadata
  { achievement-type: ACHIEVEMENT-FIRST-WIN }
  {
    name: "First Win",
    description: u"Won your first prediction market",
    image-uri: "ipfs://placeholder/first-win.png",
    enabled: true
  }
)

(map-set achievement-metadata
  { achievement-type: ACHIEVEMENT-FIVE-WINS }
  {
    name: "Rising Star",
    description: u"Won 5 prediction markets",
    image-uri: "ipfs://placeholder/five-wins.png",
    enabled: true
  }
)

(map-set achievement-metadata
  { achievement-type: ACHIEVEMENT-TEN-WINS }
  {
    name: "Prophet",
    description: u"Won 10 prediction markets",
    image-uri: "ipfs://placeholder/ten-wins.png",
    enabled: true
  }
)

(map-set achievement-metadata
  { achievement-type: ACHIEVEMENT-HUNDRED-STX-EARNED }
  {
    name: "Century Club",
    description: u"Earned 100 STX in total winnings",
    image-uri: "ipfs://placeholder/hundred-stx.png",
    enabled: true
  }
)
