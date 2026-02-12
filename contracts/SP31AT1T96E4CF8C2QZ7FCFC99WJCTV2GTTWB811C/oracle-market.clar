;; ============================================
;; ORACLE MARKET - Decentralized Prediction Market
;; ============================================
;; A blockchain-based prediction market platform where users can stake STX
;; on various outcomes of future events. Markets are created by admins and
;; resolved by trusted oracles who verify real-world outcomes.
;; 
;; Key Features:
;; - Oracle-verified market resolution for trustworthy outcomes
;; - Multi-outcome prediction markets (2-10 outcomes per market)
;; - Dynamic odds calculation based on stake distribution
;; - Platform fee collection for sustainable operations
;; - Achievement NFT system to reward active predictors
;; - Soulbound achievement tokens (non-transferable)
;;
;; ============================================
;; CONSTANTS
;; ============================================

;; Error codes - Prediction Market (100-199)
;; These errors handle market operations and oracle interactions
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-MARKET-NOT-FOUND (err u101))
(define-constant ERR-INVALID-MARKET-STATE (err u102))
(define-constant ERR-INVALID-OUTCOME (err u103))
(define-constant ERR-STAKE-TOO-LOW (err u104))
(define-constant ERR-STAKE-TOO-HIGH (err u105))
(define-constant ERR-MARKET-CLOSED (err u106))
(define-constant ERR-MARKET-NOT-RESOLVED (err u107))
(define-constant ERR-NO-WINNINGS (err u108))
(define-constant ERR-ALREADY-CLAIMED (err u109))
(define-constant ERR-INVALID-ORACLE (err u110))
(define-constant ERR-MARKET-LOCKED (err u111))
(define-constant ERR-MARKET-ALREADY-RESOLVED (err u112))
(define-constant ERR-PAUSED (err u113))
(define-constant ERR-INVALID-FEE (err u114))
(define-constant ERR-TRANSFER-FAILED (err u115))
(define-constant ERR-INVALID-PRINCIPAL (err u116))
(define-constant ERR-INVALID-OUTCOME-COUNT (err u117))
(define-constant ERR-INVALID-INPUT (err u118))
(define-constant ERR-INVALID-DATE (err u119))

;; Error codes - Achievement NFTs (200-299)
(define-constant ERR-NFT-NOT-FOUND (err u201))
(define-constant ERR-ALREADY-EXISTS (err u202))
(define-constant ERR-INVALID-ACHIEVEMENT (err u203))
(define-constant ERR-ACHIEVEMENT-LOCKED (err u204))

;; Market states - Define the lifecycle of a prediction market
;; ACTIVE: Market is open for staking
;; LOCKED: Market closed for staking, awaiting oracle resolution
;; RESOLVED: Oracle has determined the winning outcome
;; CANCELLED: Market cancelled, users can claim refunds
(define-constant STATE-ACTIVE "active")
(define-constant STATE-LOCKED "locked")
(define-constant STATE-RESOLVED "resolved")
(define-constant STATE-CANCELLED "cancelled")

;; Staking limits (in microSTX, 1 STX = 1,000,000 microSTX)
(define-constant MIN-STAKE u1000000) ;; 1 STX
(define-constant MAX-STAKE u100000000) ;; 100 STX

;; Platform fee divisor for basis points calculation
(define-constant BPS-DIVISOR u10000)

;; Achievement types - NFT rewards for Oracle Market milestones
;; These soulbound tokens recognize user participation and success
(define-constant ACHIEVEMENT-FIRST-PREDICTION u1)
(define-constant ACHIEVEMENT-FIRST-WIN u2)
(define-constant ACHIEVEMENT-FIVE-WINS u3)
(define-constant ACHIEVEMENT-TEN-WINS u4)
(define-constant ACHIEVEMENT-HUNDRED-STX-EARNED u5)

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; ============================================
;; DATA VARIABLES
;; ============================================

;; Prediction Market Variables
;; Core state variables for Oracle Market operations
(define-data-var market-id-nonce uint u0) ;; Counter for unique market IDs
(define-data-var platform-fee-bps uint u300)
(define-data-var treasury-address principal CONTRACT-OWNER)
(define-data-var contract-paused bool false)
(define-data-var oracle-address principal CONTRACT-OWNER) ;; Trusted oracle who resolves markets

;; Achievement NFT Variables
(define-data-var token-id-nonce uint u0)

;; ============================================
;; DATA MAPS
;; ============================================

;; Market data structure
;; Stores all information about prediction markets in the Oracle Market
;; Markets are created by admins and resolved by oracles
(define-map markets
  { market-id: uint }
  {
    title: (string-ascii 256),
    description: (string-utf8 1024),
    category: (string-ascii 50),
    outcomes: (list 10 (string-utf8 256)),
    outcome-count: uint,
    resolution-date: uint,
    lock-date: uint,
    state: (string-ascii 20),
    total-pool: uint,
    winning-outcome: (optional uint),
    creator: principal,
    created-at: uint
  }
)

;; Track stakes per outcome for each market
;; Aggregates total stakes on each outcome to calculate odds and payouts
(define-map outcome-pools
  { market-id: uint, outcome-index: uint }
  { total-staked: uint, staker-count: uint }
)

;; Track individual user stakes
;; Records each user's prediction and stake amount for claiming winnings
;; after oracle resolves the market
(define-map user-stakes
  { user: principal, market-id: uint, outcome-index: uint }
  { amount: uint, timestamp: uint, claimed: bool }
)

;; Achievement NFT Maps
;; Soulbound tokens that reward Oracle Market participants
;; These NFTs cannot be transferred once earned
(define-map token-owners
  { token-id: uint }
  { owner: principal }
)

(define-map user-achievements
  { user: principal, achievement-type: uint }
  { token-id: uint, earned-at: uint }
)

(define-map achievement-metadata
  { achievement-type: uint }
  {
    name: (string-ascii 50),
    description: (string-utf8 256),
    image-uri: (string-ascii 256),
    enabled: bool
  }
)

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
;; PRIVATE HELPER FUNCTIONS
;; ============================================

(define-private (get-outcome-pool (market-id uint) (outcome-index uint))
  (default-to 
    { total-staked: u0, staker-count: u0 }
    (map-get? outcome-pools { market-id: market-id, outcome-index: outcome-index })
  )
)

(define-private (get-user-stats-or-default (user principal))
  (default-to
    { total-predictions: u0, total-wins: u0, total-stx-earned: u0, achievement-count: u0 }
    (map-get? user-achievement-stats { user: user })
  )
)

;; ============================================
;; PRIVATE FUNCTIONS
;; ============================================

(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-oracle)
  ;; Validates that the caller is the trusted oracle address
  ;; Only oracles can resolve markets in the Oracle Market system
  (is-eq tx-sender (var-get oracle-address))
)

(define-private (calculate-fee (amount uint))
  ;; Calculates the Oracle Market platform fee from the total pool
  ;; Fee is collected during market resolution and sent to treasury
  (/ (* amount (var-get platform-fee-bps)) BPS-DIVISOR)
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

(define-read-only (get-market (market-id uint))
  (map-get? markets { market-id: market-id })
)

(define-read-only (get-user-stake (user principal) (market-id uint) (outcome-index uint))
  (map-get? user-stakes { user: user, market-id: market-id, outcome-index: outcome-index })
)

(define-read-only (get-outcome-pool-info (market-id uint) (outcome-index uint))
  (ok (get-outcome-pool market-id outcome-index))
)

(define-read-only (get-current-odds (market-id uint) (outcome-index uint))
  ;; Calculates real-time odds for an outcome based on stake distribution
  ;; Returns odds as basis points (10000 = 100%) for Oracle Market UI display
  (let
    (
      (market (unwrap! (get-market market-id) ERR-MARKET-NOT-FOUND))
      (total-pool (get total-pool market))
      (outcome-pool (get-outcome-pool market-id outcome-index))
      (outcome-staked (get total-staked outcome-pool))
    )
    (if (is-eq total-pool u0)
      (ok u0)
      (ok (/ (* outcome-staked u10000) total-pool))
    )
  )
)

(define-read-only (calculate-potential-winnings (market-id uint) (outcome-index uint) (stake-amount uint))
  ;; Estimates potential payout for a stake on an outcome
  ;; Helps Oracle Market users make informed prediction decisions
  ;; Accounts for platform fees and current pool distribution
  (let
    (
      (market (unwrap! (get-market market-id) ERR-MARKET-NOT-FOUND))
      (total-pool (get total-pool market))
      (outcome-pool (get-outcome-pool market-id outcome-index))
      (outcome-staked (get total-staked outcome-pool))
      (new-outcome-staked (+ outcome-staked stake-amount))
      (new-total-pool (+ total-pool stake-amount))
      (fee (calculate-fee new-total-pool))
      (distributable-pool (- new-total-pool fee))
    )
    (if (is-eq new-outcome-staked u0)
      (ok u0)
      (ok (/ (* distributable-pool stake-amount) new-outcome-staked))
    )
  )
)

(define-read-only (get-contract-info)
  (ok {
    paused: (var-get contract-paused),
    oracle: (var-get oracle-address),
    treasury: (var-get treasury-address),
    fee-bps: (var-get platform-fee-bps),
    next-market-id: (var-get market-id-nonce)
  })
)

(define-read-only (get-market-display-info (market-id uint))
  (let
    (
      (market (unwrap! (get-market market-id) ERR-MARKET-NOT-FOUND))
    )
    (ok {
      market-id: market-id,
      state: (get state market),
      total-pool: (get total-pool market),
      current-block: stacks-block-height
    })
  )
)

;; ============================================
;; READ-ONLY FUNCTIONS - ACHIEVEMENT NFTs
;; ============================================

(define-read-only (get-last-token-id)
  (ok (var-get token-id-nonce))
)

(define-read-only (get-token-uri (token-id uint))
  ;; Find which achievement type this token belongs to by checking user-achievements
  ;; This is a limitation - we'd need to store achievement-type in token-owners for direct lookup
  ;; For now, return a generic response
  (match (map-get? token-owners { token-id: token-id })
    owner-data (ok (some "ipfs://placeholder/achievement.png"))
    ERR-NFT-NOT-FOUND
  )
)

(define-read-only (get-nft-owner (token-id uint))
  (match (map-get? token-owners { token-id: token-id })
    owner-data (ok (some (get owner owner-data)))
    (ok none)
  )
)

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

(define-read-only (get-nft-contract-info)
  (ok {
    total-tokens: (var-get token-id-nonce)
  })
)

;; ============================================
;; PUBLIC FUNCTIONS - ADMIN
;; ============================================

(define-public (set-oracle-address (new-oracle principal))
  ;; Updates the trusted oracle address for the Oracle Market
  ;; Only the contract owner can designate who can resolve markets
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-standard new-oracle) ERR-INVALID-PRINCIPAL)
    (ok (var-set oracle-address new-oracle))
  )
)

(define-public (set-treasury-address (new-treasury principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-standard new-treasury) ERR-INVALID-PRINCIPAL)
    (ok (var-set treasury-address new-treasury))
  )
)

(define-public (set-platform-fee (new-fee-bps uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee-bps u1000) ERR-INVALID-FEE) ;; Max 10%
    (ok (var-set platform-fee-bps new-fee-bps))
  )
)

(define-public (toggle-pause)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (var-set contract-paused (not (var-get contract-paused))))
  )
)

;; ============================================
;; PUBLIC FUNCTIONS - MARKET CREATION
;; ============================================

(define-public (create-market 
  ;; Creates a new prediction market in the Oracle Market platform
  ;; Markets have 2-10 outcomes and require oracle resolution after lock date
  ;; Only admins can create markets to ensure quality control
  (title (string-ascii 256))
  (description (string-utf8 1024))
  (category (string-ascii 50))
  (outcomes (list 10 (string-utf8 256)))
  (resolution-date uint)
  (lock-date uint)
)
  (let
    (
      (new-market-id (var-get market-id-nonce))
      (outcome-count (len outcomes))
    )
    (asserts! (not (var-get contract-paused)) ERR-PAUSED)
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (>= outcome-count u2) ERR-INVALID-OUTCOME-COUNT) ;; At least 2 outcomes
    (asserts! (<= outcome-count u10) ERR-INVALID-OUTCOME-COUNT) ;; Max 10 outcomes
    (asserts! (> (len title) u0) ERR-INVALID-INPUT) ;; Title not empty
    (asserts! (> (len description) u0) ERR-INVALID-INPUT) ;; Description not empty
    (asserts! (> (len category) u0) ERR-INVALID-INPUT) ;; Category not empty
    (asserts! (> resolution-date stacks-block-height) ERR-INVALID-DATE) ;; Future resolution
    (asserts! (> lock-date stacks-block-height) ERR-INVALID-DATE) ;; Future lock
    (asserts! (< lock-date resolution-date) ERR-INVALID-DATE) ;; Lock before resolution
    
    ;; Create the market
    (map-set markets
      { market-id: new-market-id }
      {
        title: title,
        description: description,
        category: category,
        outcomes: outcomes,
        outcome-count: outcome-count,
        resolution-date: resolution-date,
        lock-date: lock-date,
        state: STATE-ACTIVE,
        total-pool: u0,
        winning-outcome: none,
        creator: tx-sender,
        created-at: stacks-block-height
      }
    )
    
    ;; Log market creation event
    (print {
      event: "market-created",
      market-id: new-market-id,
      creator: tx-sender,
      block-height: stacks-block-height
    })
    
    (var-set market-id-nonce (+ new-market-id u1))
    (ok new-market-id)
  )
)

;; ============================================
;; PUBLIC FUNCTIONS - STAKING
;; ============================================

(define-public (place-stake (market-id uint) (outcome-index uint) (stake-amount uint))
  ;; Allows users to stake STX on a market outcome in the Oracle Market
  ;; Stakes determine odds and potential winnings after oracle resolution
  ;; Users can only stake before the market lock date
  (let
    (
      ;; Note: market-id is validated here - unwrap! ensures market exists
      (market (unwrap! (get-market market-id) ERR-MARKET-NOT-FOUND))
      (market-state (get state market))
      (outcome-count (get outcome-count market))
      (lock-date (get lock-date market))
      (current-pool (get-outcome-pool market-id outcome-index))
      (existing-stake (map-get? user-stakes { user: tx-sender, market-id: market-id, outcome-index: outcome-index }))
    )
    (asserts! (not (var-get contract-paused)) ERR-PAUSED)
    (asserts! (is-eq market-state STATE-ACTIVE) ERR-MARKET-CLOSED)
    (asserts! (< stacks-block-height lock-date) ERR-MARKET-LOCKED)
    (asserts! (< outcome-index outcome-count) ERR-INVALID-OUTCOME)
    (asserts! (>= stake-amount MIN-STAKE) ERR-STAKE-TOO-LOW)
    (asserts! (<= stake-amount MAX-STAKE) ERR-STAKE-TOO-HIGH)
    
    ;; Transfer STX from user to contract principal
    ;; In Clarity 4, we need to get the contract's own principal using unwrap!
    (try! (stx-transfer? stake-amount tx-sender (unwrap! (as-contract? () tx-sender) ERR-TRANSFER-FAILED)))
    
    ;; Update outcome pool
    (map-set outcome-pools
      { market-id: market-id, outcome-index: outcome-index }
      {
        total-staked: (+ (get total-staked current-pool) stake-amount),
        staker-count: (if (is-none existing-stake) 
                        (+ (get staker-count current-pool) u1)
                        (get staker-count current-pool))
      }
    )
    
    ;; Update or create user stake
    (match existing-stake
      prev-stake
        (map-set user-stakes
          { user: tx-sender, market-id: market-id, outcome-index: outcome-index }
          {
            amount: (+ (get amount prev-stake) stake-amount),
            timestamp: stacks-block-height,
            claimed: false
          }
        )
      (map-set user-stakes
        { user: tx-sender, market-id: market-id, outcome-index: outcome-index }
        {
          amount: stake-amount,
          timestamp: stacks-block-height,
          claimed: false
        }
      )
    )
    
    ;; Update market total pool
    (map-set markets
      { market-id: market-id }
      (merge market { total-pool: (+ (get total-pool market) stake-amount) })
    )
    
    ;; Log stake event
    (print {
      event: "stake-placed",
      user: tx-sender,
      market-id: market-id,
      outcome-index: outcome-index,
      amount: stake-amount,
      block-height: stacks-block-height
    })
    
    ;; Track prediction for achievements
    (try! (increment-predictions tx-sender))
    
    (ok true)
  )
)

;; ============================================
;; PUBLIC FUNCTIONS - MARKET RESOLUTION
;; ============================================

(define-public (lock-market (market-id uint))
  ;; Locks a market to prevent further staking before oracle resolution
  ;; Oracle Market requires markets to be locked before resolution
  ;; Can only be called by oracle or contract owner after lock date
  (let
    (
      ;; Note: market-id is validated here - unwrap! ensures market exists
      (market (unwrap! (get-market market-id) ERR-MARKET-NOT-FOUND))
      (market-state (get state market))
      (lock-date (get lock-date market))
    )
    (asserts! (or (is-oracle) (is-contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq market-state STATE-ACTIVE) ERR-INVALID-MARKET-STATE)
    (asserts! (>= stacks-block-height lock-date) ERR-INVALID-DATE)
    
    (map-set markets
      { market-id: market-id }
      (merge market { state: STATE-LOCKED })
    )
    (ok true)
  )
)

(define-public (resolve-market (market-id uint) (winning-outcome-index uint))
  ;; Oracle resolves the market by declaring the winning outcome
  ;; This is the core Oracle Market function - oracle verifies real-world results
  ;; Platform fee is collected and sent to treasury upon resolution
  ;; Only the designated oracle can call this function
  (let
    (
      (market (unwrap! (get-market market-id) ERR-MARKET-NOT-FOUND))
      (market-state (get state market))
      (outcome-count (get outcome-count market))
      (resolution-date (get resolution-date market))
      (total-pool (get total-pool market))
      (fee-amount (calculate-fee total-pool))
    )
    (asserts! (is-oracle) ERR-INVALID-ORACLE)
    (asserts! (or (is-eq market-state STATE-LOCKED) (is-eq market-state STATE-ACTIVE)) ERR-MARKET-ALREADY-RESOLVED)
    (asserts! (>= stacks-block-height resolution-date) ERR-INVALID-DATE)
    (asserts! (< winning-outcome-index outcome-count) ERR-INVALID-OUTCOME)
    
    ;; Transfer platform fee to treasury
    (if (> fee-amount u0)
      (begin
        (try! (as-contract? ((with-stx fee-amount)) (try! (stx-transfer? fee-amount tx-sender (var-get treasury-address)))))
        true
      )
      true
    )
    
    ;; Update market state
    (map-set markets
      { market-id: market-id }
      (merge market { 
        state: STATE-RESOLVED,
        winning-outcome: (some winning-outcome-index)
      })
    )
    
    ;; Log resolution event
    (print {
      event: "market-resolved",
      market-id: market-id,
      winning-outcome: winning-outcome-index,
      total-pool: total-pool,
      fee-collected: fee-amount,
      resolved-by: tx-sender,
      block-height: stacks-block-height
    })
    
    (ok true)
  )
)

;; ============================================
;; PUBLIC FUNCTIONS - CLAIMING WINNINGS
;; ============================================

(define-public (claim-winnings (market-id uint))
  ;; Users claim their winnings from correctly predicted outcomes
  ;; After oracle resolves market, winners receive proportional share of pool
  ;; Winnings are calculated minus platform fees
  ;; Triggers achievement NFT minting for Oracle Market milestones
  (let
    (
      (market (unwrap! (get-market market-id) ERR-MARKET-NOT-FOUND))
      (market-state (get state market))
      (winning-outcome (unwrap! (get winning-outcome market) ERR-MARKET-NOT-RESOLVED))
      (user-stake (unwrap! (get-user-stake tx-sender market-id winning-outcome) ERR-NO-WINNINGS))
      (user-amount (get amount user-stake))
      (already-claimed (get claimed user-stake))
      (total-pool (get total-pool market))
      (fee-amount (calculate-fee total-pool))
      (distributable-pool (- total-pool fee-amount))
      (winning-pool (get-outcome-pool market-id winning-outcome))
      (winning-total (get total-staked winning-pool))
      (user-winnings (/ (* distributable-pool user-amount) winning-total))
      (recipient tx-sender)
    )
    (asserts! (is-eq market-state STATE-RESOLVED) ERR-MARKET-NOT-RESOLVED)
    (asserts! (not already-claimed) ERR-ALREADY-CLAIMED)
    (asserts! (> user-amount u0) ERR-NO-WINNINGS)
    
    ;; Mark as claimed
    (map-set user-stakes
      { user: tx-sender, market-id: market-id, outcome-index: winning-outcome }
      (merge user-stake { claimed: true })
    )
    
    ;; Transfer winnings from contract to user
    (if (> user-winnings u0)
      (begin
        (try! (as-contract? ((with-stx user-winnings)) (try! (stx-transfer? user-winnings tx-sender recipient))))
        true
      )
      true
    )
    
    ;; Log claim event
    (print {
      event: "winnings-claimed",
      user: tx-sender,
      market-id: market-id,
      amount: user-winnings,
      block-height: stacks-block-height
    })
    
    ;; Track win and earnings for achievements
    (try! (increment-wins tx-sender))
    (try! (add-stx-earned tx-sender user-winnings))
    
    (ok user-winnings)
  )
)

;; ============================================
;; PUBLIC FUNCTIONS - ACHIEVEMENT NFTs
;; ============================================

(define-public (set-achievement-metadata
  (achievement-type uint)
  (name (string-ascii 50))
  (description (string-utf8 256))
  (image-uri (string-ascii 256))
  (enabled bool)
)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)
    (asserts! (> (len image-uri) u0) ERR-INVALID-INPUT)
    (asserts! (<= achievement-type u5) ERR-INVALID-ACHIEVEMENT) ;; Valid achievement type
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

(define-public (transfer-nft (token-id uint) (sender principal) (recipient principal))
  ;; Achievement NFTs are soulbound - cannot be transferred
  ;; Oracle Market achievements are tied to the user who earned them
  ;; This ensures authentic reputation and prevents gaming the system
  ERR-ACHIEVEMENT-LOCKED
)

;; Private function to mint achievement without authorization check (for auto-minting)
(define-private (mint-achievement-internal (user principal) (achievement-type uint))
  (let
    (
      (new-token-id (var-get token-id-nonce))
      (existing-achievement (get-user-achievement user achievement-type))
      (metadata (unwrap! (map-get? achievement-metadata { achievement-type: achievement-type }) ERR-INVALID-ACHIEVEMENT))
      (user-stats (get-user-stats-or-default user))
    )
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
    
    ;; Log achievement mint event
    (print {
      event: "achievement-minted",
      user: user,
      achievement-type: achievement-type,
      token-id: new-token-id,
      block-height: stacks-block-height
    })
    
    (ok new-token-id)
  )
)

(define-public (mint-achievement (user principal) (achievement-type uint))
  ;; Mints achievement NFTs to reward Oracle Market participation
  ;; Public function for admin to manually mint achievements
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (mint-achievement-internal user achievement-type)
  )
)

;; ============================================
;; PRIVATE FUNCTIONS - STAT TRACKING
;; ============================================

(define-private (increment-predictions (user principal))
  ;; Tracks user prediction activity in Oracle Market for achievements
  ;; Automatically mints "First Prediction" achievement NFT
  (let
    (
      (stats (get-user-stats-or-default user))
      (new-total (+ (get total-predictions stats) u1))
    )
    (map-set user-achievement-stats
      { user: user }
      (merge stats { total-predictions: new-total })
    )
    
    ;; Log prediction increment
    (print {
      event: "prediction-tracked",
      user: user,
      total-predictions: new-total,
      block-height: stacks-block-height
    })
    
    ;; Auto-mint first prediction achievement
    (if (is-eq new-total u1)
      (mint-achievement-internal user ACHIEVEMENT-FIRST-PREDICTION)
      (ok u0)
    )
  )
)

(define-private (increment-wins (user principal))
  ;; Tracks successful predictions in Oracle Market for win-based achievements
  ;; Automatically mints NFTs at 1, 5, and 10 wins milestones
  (let
    (
      (stats (get-user-stats-or-default user))
      (new-total (+ (get total-wins stats) u1))
    )
    (map-set user-achievement-stats
      { user: user }
      (merge stats { total-wins: new-total })
    )
    
    ;; Log win increment
    (print {
      event: "win-tracked",
      user: user,
      total-wins: new-total,
      block-height: stacks-block-height
    })
    
    ;; Auto-mint win achievements
    (if (is-eq new-total u1)
      (mint-achievement-internal user ACHIEVEMENT-FIRST-WIN)
      (if (is-eq new-total u5)
        (mint-achievement-internal user ACHIEVEMENT-FIVE-WINS)
        (if (is-eq new-total u10)
          (mint-achievement-internal user ACHIEVEMENT-TEN-WINS)
          (ok u0)
        )
      )
    )
  )
)

(define-private (add-stx-earned (user principal) (amount uint))
  ;; Tracks total STX earnings in Oracle Market for wealth-based achievements
  ;; Automatically mints "Century Club" achievement at 100 STX earned
  (let
    (
      (stats (get-user-stats-or-default user))
      (new-total (+ (get total-stx-earned stats) amount))
    )
    (map-set user-achievement-stats
      { user: user }
      (merge stats { total-stx-earned: new-total })
    )
    
    ;; Log STX earned increment
    (print {
      event: "stx-earned-tracked",
      user: user,
      amount: amount,
      total-earned: new-total,
      block-height: stacks-block-height
    })
    
    ;; Auto-mint STX earned achievement (100 STX = 100,000,000 microSTX)
    (if (>= new-total u100000000)
      (mint-achievement-internal user ACHIEVEMENT-HUNDRED-STX-EARNED)
      (ok u0)
    )
  )
)

;; ============================================
;; INITIALIZATION
;; ============================================

;; Initialize default achievement metadata
;; These are the default Oracle Market achievement NFTs that reward user milestones
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

;; ============================================
;; PUBLIC FUNCTIONS - MARKET CANCELLATION
;; ============================================

(define-public (cancel-market (market-id uint))
  ;; Cancels a market in the Oracle Market if needed (emergency or invalid market)
  ;; Users can claim full refunds when markets are cancelled
  ;; Only contract owner can cancel markets to prevent oracle manipulation
  (let
    (
      ;; Note: market-id is validated here - unwrap! ensures market exists
      (market (unwrap! (get-market market-id) ERR-MARKET-NOT-FOUND))
      (market-state (get state market))
    )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq market-state STATE-RESOLVED)) ERR-MARKET-ALREADY-RESOLVED)
    
    (map-set markets
      { market-id: market-id }
      (merge market { state: STATE-CANCELLED })
    )
    (ok true)
  )
)

(define-public (claim-refund (market-id uint) (outcome-index uint))
  ;; Allows users to claim full refunds from cancelled Oracle Market markets
  ;; No fees are deducted for refunds, users get back their original stakes
  (let
    (
      ;; Note: market-id and outcome-index validated - unwrap! ensures data exists
      (market (unwrap! (get-market market-id) ERR-MARKET-NOT-FOUND))
      (market-state (get state market))
      (user-stake (unwrap! (get-user-stake tx-sender market-id outcome-index) ERR-NO-WINNINGS))
      (user-amount (get amount user-stake))
      (already-claimed (get claimed user-stake))
      (recipient tx-sender)
    )
    (asserts! (is-eq market-state STATE-CANCELLED) ERR-INVALID-MARKET-STATE)
    (asserts! (not already-claimed) ERR-ALREADY-CLAIMED)
    (asserts! (> user-amount u0) ERR-NO-WINNINGS)
    
    ;; Mark as claimed
    (map-set user-stakes
      { user: tx-sender, market-id: market-id, outcome-index: outcome-index }
      (merge user-stake { claimed: true })
    )
    
    ;; Refund full amount from contract to user
    (if (> user-amount u0)
      (begin
        (try! (as-contract? ((with-stx user-amount)) (try! (stx-transfer? user-amount tx-sender recipient))))
        true
      )
      true
    )
    
    (ok user-amount)
  )
)

(define-public (update-market 
  (market-id uint) 
  (title (string-ascii 256)) 
  (description (string-utf8 1024)) 
  (category (string-ascii 50))
)
  (let
    (
      (market (unwrap! (get-market market-id) ERR-MARKET-NOT-FOUND))
    )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (> (len title) u0) ERR-INVALID-INPUT)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)
    (asserts! (> (len category) u0) ERR-INVALID-INPUT)
    
    (map-set markets
      { market-id: market-id }
      (merge market { 
        title: title, 
        description: description, 
        category: category 
      })
    )
    (ok true)
  )
)
