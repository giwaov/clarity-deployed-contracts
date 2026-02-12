;; PopPredict - Decentralized Pop Culture Prediction Market
;; A prediction market for entertainment and pop culture events
;; Version: 1.0.0

;; ============================================
;; CONSTANTS
;; ============================================

;; Error codes
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

;; Market states
(define-constant STATE-ACTIVE "active")
(define-constant STATE-LOCKED "locked")
(define-constant STATE-RESOLVED "resolved")
(define-constant STATE-CANCELLED "cancelled")

;; Staking limits (in microSTX, 1 STX = 1,000,000 microSTX)
(define-constant MIN-STAKE u1000000) ;; 1 STX
(define-constant MAX-STAKE u100000000) ;; 100 STX

;; Platform fee (3% = 300 basis points)
(define-constant PLATFORM-FEE-BPS u300)
(define-constant BPS-DIVISOR u10000)

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; ============================================
;; DATA VARIABLES
;; ============================================

(define-data-var market-id-nonce uint u0)
(define-data-var platform-fee-bps uint u300)
(define-data-var treasury-address principal CONTRACT-OWNER)
(define-data-var contract-paused bool false)
(define-data-var oracle-address principal CONTRACT-OWNER)

;; ============================================
;; DATA MAPS
;; ============================================

;; Market data structure
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
(define-map outcome-pools
  { market-id: uint, outcome-index: uint }
  { total-staked: uint, staker-count: uint }
)

;; Track individual user stakes
(define-map user-stakes
  { user: principal, market-id: uint, outcome-index: uint }
  { amount: uint, timestamp: uint, claimed: bool }
)

;; Track total stakes per user per market (for claim checking)
(define-map user-market-stakes
  { user: principal, market-id: uint }
  { total-amount: uint, outcome-index: uint }
)

;; Authorized market creators (for future expansion)
(define-map authorized-creators
  { creator: principal }
  { authorized: bool }
)

;; ============================================
;; PRIVATE FUNCTIONS
;; ============================================

(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-authorized-creator)
  (or
    (is-contract-owner)
    (default-to false (get authorized (map-get? authorized-creators { creator: tx-sender })))
  )
)

(define-private (is-oracle)
  (is-eq tx-sender (var-get oracle-address))
)

(define-private (calculate-fee (amount uint))
  (/ (* amount (var-get platform-fee-bps)) BPS-DIVISOR)
)

(define-private (get-outcome-pool (market-id uint) (outcome-index uint))
  (default-to 
    { total-staked: u0, staker-count: u0 }
    (map-get? outcome-pools { market-id: market-id, outcome-index: outcome-index })
  )
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

(define-read-only (get-user-market-position (user principal) (market-id uint))
  (map-get? user-market-stakes { user: user, market-id: market-id })
)

(define-read-only (get-outcome-pool-info (market-id uint) (outcome-index uint))
  (ok (get-outcome-pool market-id outcome-index))
)

(define-read-only (get-current-odds (market-id uint) (outcome-index uint))
  (let
    (
      (market (unwrap! (get-market market-id) ERR-MARKET-NOT-FOUND))
      (total-pool (get total-pool market))
      (outcome-pool (get-outcome-pool market-id outcome-index))
      (outcome-staked (get total-staked outcome-pool))
    )
    (if (is-eq outcome-staked u0)
      (ok u0)
      (ok (/ (* total-pool u100) outcome-staked))
    )
  )
)

(define-read-only (calculate-potential-winnings (market-id uint) (outcome-index uint) (stake-amount uint))
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

;; Clarity 4: Get contract hash for verification
(define-read-only (get-contract-verification)
  (ok {
    contract-hash: (contract-hash? .pop-predict)
  })
)

;; Clarity 4: Get market info with readable display using to-ascii
;; Note: Uncomment when deploying with Clarity 4 support (requires to-ascii? function)
;; (define-read-only (get-market-display-info (market-id uint))
;;   (let
;;     (
;;       (market (unwrap! (get-market market-id) ERR-MARKET-NOT-FOUND))
;;     )
;;     (ok {
;;       market-id-str: (unwrap! (to-ascii? market-id) (err u999)),
;;       state: (get state market),
;;       total-pool: (get total-pool market),
;;       current-time: stacks-block-time,
;;       current-block: stacks-block-height
;;     })
;;   )
;; )

;; Alternative market display info without to-ascii (Clarity 3 compatible)
(define-read-only (get-market-display-info (market-id uint))
  (let
    (
      (market (unwrap! (get-market market-id) ERR-MARKET-NOT-FOUND))
    )
    (ok {
      market-id: market-id,
      state: (get state market),
      total-pool: (get total-pool market),
      current-burn-block: burn-block-height,  ;; Clarity 4: Replace with stacks-block-time
      current-block: stacks-block-height
    })
  )
)

;; ============================================
;; PUBLIC FUNCTIONS - ADMIN
;; ============================================

(define-public (set-oracle-address (new-oracle principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (var-set oracle-address new-oracle))
  )
)

(define-public (set-treasury-address (new-treasury principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
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

(define-public (authorize-creator (creator principal) (authorized bool))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-creators { creator: creator } { authorized: authorized }))
  )
)

;; ============================================
;; PUBLIC FUNCTIONS - MARKET CREATION
;; ============================================

(define-public (create-market 
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
    (asserts! (is-authorized-creator) ERR-NOT-AUTHORIZED)
    (asserts! (>= outcome-count u2) (err u116)) ;; At least 2 outcomes
    (asserts! (<= outcome-count u10) (err u117)) ;; Max 10 outcomes
    (asserts! (> resolution-date stacks-block-height) (err u118)) ;; Future resolution
    (asserts! (> lock-date stacks-block-height) (err u119)) ;; Future lock
    (asserts! (< lock-date resolution-date) (err u120)) ;; Lock before resolution
    
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
    
    ;; Clarity 4: Log market creation event (using burn-block-height for Clarity 3 compatibility)
    (print {
      event: "market-created",
      market-id: new-market-id,
      creator: tx-sender,
      burn-block: burn-block-height,  ;; Clarity 4: Replace with stacks-block-time
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
  (let
    (
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
    
    ;; Transfer STX from user to contract (using Clarity 4's current-contract)
    (unwrap! (stx-transfer? stake-amount tx-sender current-contract) ERR-TRANSFER-FAILED)
    
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
    
    ;; Update user market position tracker
    (map-set user-market-stakes
      { user: tx-sender, market-id: market-id }
      {
        total-amount: stake-amount,
        outcome-index: outcome-index
      }
    )
    
    ;; Update market total pool
    (map-set markets
      { market-id: market-id }
      (merge market { total-pool: (+ (get total-pool market) stake-amount) })
    )
    
    ;; Clarity 4: Log stake event with timestamp
    (print {
      event: "stake-placed",
      user: tx-sender,
      market-id: market-id,
      outcome-index: outcome-index,
      amount: stake-amount,
      timestamp: stacks-block-time,
      block-height: stacks-block-height
    })
    
    (ok true)
  )
)

;; ============================================
;; PUBLIC FUNCTIONS - MARKET RESOLUTION
;; ============================================

(define-public (lock-market (market-id uint))
  (let
    (
      (market (unwrap! (get-market market-id) ERR-MARKET-NOT-FOUND))
      (market-state (get state market))
      (lock-date (get lock-date market))
    )
    (asserts! (or (is-oracle) (is-contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq market-state STATE-ACTIVE) ERR-INVALID-MARKET-STATE)
    (asserts! (>= stacks-block-height lock-date) (err u121))
    
    (map-set markets
      { market-id: market-id }
      (merge market { state: STATE-LOCKED })
    )
    (ok true)
  )
)

(define-public (resolve-market (market-id uint) (winning-outcome-index uint))
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
    (asserts! (>= stacks-block-height resolution-date) (err u122))
    (asserts! (< winning-outcome-index outcome-count) ERR-INVALID-OUTCOME)
    
    ;; Transfer platform fee to treasury (using Clarity 4's current-contract)
    (if (> fee-amount u0)
      (unwrap! (stx-transfer? fee-amount current-contract (var-get treasury-address)) ERR-TRANSFER-FAILED)
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
    
    ;; Clarity 4: Log resolution event (using burn-block-height for Clarity 3 compatibility)
    (print {
      event: "market-resolved",
      market-id: market-id,
      winning-outcome: winning-outcome-index,
      total-pool: total-pool,
      fee-collected: fee-amount,
      burn-block: burn-block-height,  ;; Clarity 4: Replace with stacks-block-time
      resolved-by: tx-sender
    })
    
    (ok true)
  )
)

;; ============================================
;; PUBLIC FUNCTIONS - CLAIMING WINNINGS
;; ============================================

(define-public (claim-winnings (market-id uint))
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
    )
    (asserts! (is-eq market-state STATE-RESOLVED) ERR-MARKET-NOT-RESOLVED)
    (asserts! (not already-claimed) ERR-ALREADY-CLAIMED)
    (asserts! (> user-amount u0) ERR-NO-WINNINGS)
    
    ;; Mark as claimed
    (map-set user-stakes
      { user: tx-sender, market-id: market-id, outcome-index: winning-outcome }
      (merge user-stake { claimed: true })
    )
    
    ;; Transfer winnings (using Clarity 4's current-contract)
    (unwrap! (stx-transfer? user-winnings current-contract tx-sender) ERR-TRANSFER-FAILED)
    
    ;; Clarity 4: Log claim event (using burn-block-height for Clarity 3 compatibility)
    (print {
      event: "winnings-claimed",
      user: tx-sender,
      market-id: market-id,
      amount: user-winnings,
      burn-block: burn-block-height  ;; Clarity 4: Replace with stacks-block-time
    })
    
    (ok user-winnings)
  )
)

;; ============================================
;; PUBLIC FUNCTIONS - MARKET CANCELLATION
;; ============================================

(define-public (cancel-market (market-id uint))
  (let
    (
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
  (let
    (
      (market (unwrap! (get-market market-id) ERR-MARKET-NOT-FOUND))
      (market-state (get state market))
      (user-stake (unwrap! (get-user-stake tx-sender market-id outcome-index) ERR-NO-WINNINGS))
      (user-amount (get amount user-stake))
      (already-claimed (get claimed user-stake))
    )
    (asserts! (is-eq market-state STATE-CANCELLED) ERR-INVALID-MARKET-STATE)
    (asserts! (not already-claimed) ERR-ALREADY-CLAIMED)
    (asserts! (> user-amount u0) ERR-NO-WINNINGS)
    
    ;; Mark as claimed
    (map-set user-stakes
      { user: tx-sender, market-id: market-id, outcome-index: outcome-index }
      (merge user-stake { claimed: true })
    )
    
    ;; Refund full amount (using Clarity 4's current-contract)
    (unwrap! (stx-transfer? user-amount current-contract tx-sender) ERR-TRANSFER-FAILED)
    
    (ok user-amount)
  )
)

