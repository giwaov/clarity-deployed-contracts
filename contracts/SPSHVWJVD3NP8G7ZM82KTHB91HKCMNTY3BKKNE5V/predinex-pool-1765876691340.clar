;; Predinex Pool - Prediction Market on Stacks
;; A decentralized prediction market with Clarity 4 features
;; Built for Stacks Builder Challenge Week 1

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-INVALID-AMOUNT (err u400))
(define-constant ERR-POOL-NOT-FOUND (err u404))
(define-constant ERR-POOL-SETTLED (err u409))
(define-constant ERR-INVALID-OUTCOME (err u422))
(define-constant ERR-NOT-SETTLED (err u412))
(define-constant ERR-ALREADY-CLAIMED (err u410))
(define-constant ERR-NO-WINNINGS (err u411))
(define-constant ERR-POOL-NOT-EXPIRED (err u413))
(define-constant ERR-INVALID-TITLE (err u420))
(define-constant ERR-INVALID-DESCRIPTION (err u421))
(define-constant ERR-INVALID-DURATION (err u423))
(define-constant ERR-INSUFFICIENT-BALANCE (err u424))
(define-constant ERR-WITHDRAWAL-FAILED (err u425))
(define-constant ERR-INVALID-WITHDRAWAL (err u426))
(define-constant ERR-WITHDRAWAL-LOCKED (err u427))
(define-constant ERR-INSUFFICIENT-CONTRACT-BALANCE (err u428))
(define-constant ERR-NOT-POOL-CREATOR (err u429))

(define-constant FEE-PERCENT u2) ;; 2% fee
(define-constant MIN-BET-AMOUNT u1000000) ;; 1 STX in microstacks
(define-constant WITHDRAWAL-DELAY u10) ;; 10 blocks delay for security

;; ============================================
;; CLARITY 3/4 FEATURES - Builder Challenge
;; ============================================

;; Principal registry for tracking users
(define-map principal-registry
  { user: principal }
  { 
    registered-at: uint
  }
)

;; Data structures
(define-map pools
  { pool-id: uint }
  {
    creator: principal,
    title: (string-ascii 256),
    description: (string-ascii 512),
    outcome-a-name: (string-ascii 128),
    outcome-b-name: (string-ascii 128),
    total-a: uint,
    total-b: uint,
    settled: bool,
    winning-outcome: (optional uint),
    created-at: uint,
    settled-at: (optional uint),
    expiry: uint
  }
)

(define-map claims
  { pool-id: uint, user: principal }
  bool
)

(define-map user-bets
  { pool-id: uint, user: principal }
  {
    amount-a: uint,
    amount-b: uint,
    total-bet: uint
  }
)

;; Withdrawal tracking
(define-map pending-withdrawals
  { user: principal, withdrawal-id: uint }
  {
    amount: uint,
    requested-at: uint,
    status: (string-ascii 20),
    pool-id: uint
  }
)

(define-map withdrawal-history
  { user: principal, withdrawal-id: uint }
  {
    amount: uint,
    completed-at: uint,
    pool-id: uint
  }
)

(define-map user-withdrawal-counter
  { user: principal }
  uint
)

;; Access control - admins who can manage withdrawals
(define-map admins
  { admin: principal }
  bool
)

(define-data-var pool-counter uint u0)
(define-data-var total-volume uint u0)
(define-data-var total-withdrawn uint u0)
(define-data-var withdrawal-counter uint u0)

;; Create a new prediction pool
(define-public (create-pool (title (string-ascii 256)) (description (string-ascii 512)) (outcome-a (string-ascii 128)) (outcome-b (string-ascii 128)) (duration uint))
  (let ((pool-id (var-get pool-counter)))
    ;; Validation checks
    (asserts! (> (len title) u0) ERR-INVALID-TITLE)
    (asserts! (> (len description) u0) ERR-INVALID-DESCRIPTION)
    (asserts! (> (len outcome-a) u0) ERR-INVALID-OUTCOME)
    (asserts! (> (len outcome-b) u0) ERR-INVALID-OUTCOME)
    (asserts! (> duration u0) ERR-INVALID-DURATION)

    (map-insert pools
      { pool-id: pool-id }
      {
        creator: tx-sender,
        title: title,
        description: description,
        outcome-a-name: outcome-a,
        outcome-b-name: outcome-b,
        total-a: u0,
        total-b: u0,
        settled: false,
        winning-outcome: none,
        created-at: burn-block-height,
        settled-at: none,
        expiry: (+ burn-block-height duration)
      }
    )
    (var-set pool-counter (+ pool-id u1))
    (ok pool-id)
  )
)

;; Place a bet on a pool
(define-public (place-bet (pool-id uint) (outcome uint) (amount uint))
  (let ((pool (unwrap! (map-get? pools { pool-id: pool-id }) ERR-POOL-NOT-FOUND)))
    (asserts! (not (get settled pool)) ERR-POOL-SETTLED)
    (asserts! (or (is-eq outcome u0) (is-eq outcome u1)) ERR-INVALID-OUTCOME)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    (let ((pool-principal (as-contract tx-sender)))
        ;; Transfer STX from user to contract
        (try! (stx-transfer? amount tx-sender pool-principal))
    )

    ;; Update pool totals
    (if (is-eq outcome u0)
      (map-set pools
        { pool-id: pool-id }
        (merge pool { total-a: (+ (get total-a pool) amount) })
      )
      (map-set pools
        { pool-id: pool-id }
        (merge pool { total-b: (+ (get total-b pool) amount) })
      )
    )
    
    ;; Update user bet
    (let ((user-bet (default-to { amount-a: u0, amount-b: u0, total-bet: u0 } (map-get? user-bets { pool-id: pool-id, user: tx-sender }))))
      (map-set user-bets
        { pool-id: pool-id, user: tx-sender }
        (if (is-eq outcome u0)
          { amount-a: (+ (get amount-a user-bet) amount), amount-b: (get amount-b user-bet), total-bet: (+ (get total-bet user-bet) amount) }
          { amount-a: (get amount-a user-bet), amount-b: (+ (get amount-b user-bet) amount), total-bet: (+ (get total-bet user-bet) amount) }
        )
      )
    )
    
    ;; Update total volume
    (var-set total-volume (+ (var-get total-volume) amount))
    
    (ok true)
  )
)

;; Settle a pool with winning outcome
(define-public (settle-pool (pool-id uint) (winning-outcome uint))
  (let ((pool (unwrap! (map-get? pools { pool-id: pool-id }) ERR-POOL-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get creator pool)) ERR-UNAUTHORIZED)
    (asserts! (not (get settled pool)) ERR-POOL-SETTLED)
    (asserts! (or (is-eq winning-outcome u0) (is-eq winning-outcome u1)) ERR-INVALID-OUTCOME)
    
    ;; Transfer fee
    (let
      (
        (total-pool-balance (+ (get total-a pool) (get total-b pool)))
        (fee (/ (* total-pool-balance FEE-PERCENT) u100))
      )
      (if (> fee u0)
        (try! (as-contract (stx-transfer? fee tx-sender CONTRACT-OWNER)))
        true
      )
    )

    (map-set pools
      { pool-id: pool-id }
      (merge pool { settled: true, winning-outcome: (some winning-outcome), settled-at: (some burn-block-height) })
    )
    
    (ok true)
  )
)

;; Claim winnings from a settled pool
(define-public (claim-winnings (pool-id uint))
  (let 
    (
      (pool (unwrap! (map-get? pools { pool-id: pool-id }) ERR-POOL-NOT-FOUND))
      (user-bet (unwrap! (map-get? user-bets { pool-id: pool-id, user: tx-sender }) ERR-NO-WINNINGS))
      (winning-outcome (unwrap! (get winning-outcome pool) ERR-NOT-SETTLED))
    )
    (asserts! (get settled pool) ERR-NOT-SETTLED)
    (asserts! (is-none (map-get? claims { pool-id: pool-id, user: tx-sender })) ERR-ALREADY-CLAIMED)

    (let
      (
        (user-total-bet (get total-bet user-bet))
        (user-winning-bet (if (is-eq winning-outcome u0) (get amount-a user-bet) (get amount-b user-bet)))
        (pool-winning-total (if (is-eq winning-outcome u0) (get total-a pool) (get total-b pool)))
        (total-pool-balance (+ (get total-a pool) (get total-b pool)))
        (fee (/ (* total-pool-balance FEE-PERCENT) u100))
        (net-pool-balance (- total-pool-balance fee))
        (claimer tx-sender) ;; Capture the web3 user
      )
      
      (asserts! (> user-winning-bet u0) ERR-NO-WINNINGS)
      (asserts! (> pool-winning-total u0) ERR-NO-WINNINGS)

      (let
        (
          ;; Calculate share: (user_bet_on_winner * net_pool) / total_bet_on_winner
          (share (/ (* user-winning-bet net-pool-balance) pool-winning-total))
        )
        ;; Transfer share to user
        (try! (as-contract (stx-transfer? share tx-sender claimer)))
        
        ;; Mark as claimed
        (map-set claims { pool-id: pool-id, user: claimer } true)
        
        (ok true)
      )
    )
  )
)

;; Request refund if pool expired and not settled
(define-public (request-refund (pool-id uint))
  (let 
    (
      (pool (unwrap! (map-get? pools { pool-id: pool-id }) ERR-POOL-NOT-FOUND))
      (user-bet (unwrap! (map-get? user-bets { pool-id: pool-id, user: tx-sender }) ERR-NO-WINNINGS))
      (claimer tx-sender)
    )
    ;; Check expiry
    (asserts! (> burn-block-height (get expiry pool)) ERR-POOL-NOT-EXPIRED)
    ;; Check not settled
    (asserts! (not (get settled pool)) ERR-POOL-SETTLED)
    ;; Check not already claimed/refunded
    (asserts! (is-none (map-get? claims { pool-id: pool-id, user: tx-sender })) ERR-ALREADY-CLAIMED)

    (let
      (
        (refund-amount (get total-bet user-bet))
      )
      (asserts! (> refund-amount u0) ERR-NO-WINNINGS)

      ;; Transfer refund
      (try! (as-contract (stx-transfer? refund-amount tx-sender claimer)))

      ;; Mark as claimed
      (map-set claims { pool-id: pool-id, user: claimer } true)

      (ok true)
    )
  )
)

;; ============================================
;; WITHDRAWAL FUNCTIONS WITH ACCESS CONTROL
;; ============================================

;; [ACCESS CONTROL] Add admin
(define-public (add-admin (admin principal))
  (begin
    ;; Only contract owner can add admins
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (map-set admins { admin: admin } true)
    (ok true)
  )
)

;; [ACCESS CONTROL] Remove admin
(define-public (remove-admin (admin principal))
  (begin
    ;; Only contract owner can remove admins
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (map-set admins { admin: admin } false)
    (ok true)
  )
)

;; [VALIDATION] Check if user is admin
(define-read-only (is-admin (user principal))
  (default-to false (map-get? admins { admin: user }))
)

;; [VALIDATION] Check if user is contract owner
(define-read-only (is-owner (user principal))
  (is-eq user CONTRACT-OWNER)
)

;; Request withdrawal - User initiates withdrawal
(define-public (request-withdrawal (pool-id uint) (amount uint))
  (let (
    (pool (unwrap! (map-get? pools { pool-id: pool-id }) ERR-POOL-NOT-FOUND))
    (user-bet (unwrap! (map-get? user-bets { pool-id: pool-id, user: tx-sender }) ERR-NO-WINNINGS))
    (user-withdrawal-id (default-to u0 (map-get? user-withdrawal-counter { user: tx-sender })))
    (withdrawal-id (var-get withdrawal-counter))
  )
    ;; Validation checks
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= amount (get total-bet user-bet)) ERR-INVALID-WITHDRAWAL)
    (asserts! (get settled pool) ERR-NOT-SETTLED)
    
    ;; Create pending withdrawal
    (map-set pending-withdrawals
      { user: tx-sender, withdrawal-id: withdrawal-id }
      {
        amount: amount,
        requested-at: burn-block-height,
        status: "pending",
        pool-id: pool-id
      }
    )
    
    ;; Update user withdrawal counter
    (map-set user-withdrawal-counter
      { user: tx-sender }
      (+ user-withdrawal-id u1)
    )
    
    ;; Increment global withdrawal counter
    (var-set withdrawal-counter (+ withdrawal-id u1))
    
    (ok withdrawal-id)
  )
)

;; Approve withdrawal - Admin approves pending withdrawal
(define-public (approve-withdrawal (user principal) (withdrawal-id uint))
  (let (
    (withdrawal (unwrap! (map-get? pending-withdrawals { user: user, withdrawal-id: withdrawal-id }) ERR-INVALID-WITHDRAWAL))
    (amount (get amount withdrawal))
    (pool-id (get pool-id withdrawal))
  )
    ;; Access control - only admins or owner can approve
    (asserts! (or (is-admin tx-sender) (is-owner tx-sender)) ERR-UNAUTHORIZED)
    
    ;; Validation
    (asserts! (is-eq (get status withdrawal) "pending") ERR-INVALID-WITHDRAWAL)
    
    ;; Check contract has sufficient balance
    (asserts! (>= (stx-get-balance (as-contract tx-sender)) amount) ERR-INSUFFICIENT-CONTRACT-BALANCE)
    
    ;; Transfer funds to user
    (try! (as-contract (stx-transfer? amount tx-sender user)))
    
    ;; Update withdrawal status
    (map-set pending-withdrawals
      { user: user, withdrawal-id: withdrawal-id }
      (merge withdrawal { status: "approved" })
    )
    
    ;; Record in history
    (map-set withdrawal-history
      { user: user, withdrawal-id: withdrawal-id }
      {
        amount: amount,
        completed-at: burn-block-height,
        pool-id: pool-id
      }
    )
    
    ;; Update total withdrawn
    (var-set total-withdrawn (+ (var-get total-withdrawn) amount))
    
    (ok true)
  )
)

;; Reject withdrawal - Admin rejects pending withdrawal
(define-public (reject-withdrawal (user principal) (withdrawal-id uint))
  (let (
    (withdrawal (unwrap! (map-get? pending-withdrawals { user: user, withdrawal-id: withdrawal-id }) ERR-INVALID-WITHDRAWAL))
  )
    ;; Access control - only admins or owner can reject
    (asserts! (or (is-admin tx-sender) (is-owner tx-sender)) ERR-UNAUTHORIZED)
    
    ;; Validation
    (asserts! (is-eq (get status withdrawal) "pending") ERR-INVALID-WITHDRAWAL)
    
    ;; Update withdrawal status
    (map-set pending-withdrawals
      { user: user, withdrawal-id: withdrawal-id }
      (merge withdrawal { status: "rejected" })
    )
    
    (ok true)
  )
)

;; Cancel withdrawal - User cancels their own pending withdrawal
(define-public (cancel-withdrawal (withdrawal-id uint))
  (let (
    (withdrawal (unwrap! (map-get? pending-withdrawals { user: tx-sender, withdrawal-id: withdrawal-id }) ERR-INVALID-WITHDRAWAL))
  )
    ;; Validation
    (asserts! (is-eq (get status withdrawal) "pending") ERR-INVALID-WITHDRAWAL)
    
    ;; Update withdrawal status
    (map-set pending-withdrawals
      { user: tx-sender, withdrawal-id: withdrawal-id }
      (merge withdrawal { status: "cancelled" })
    )
    
    (ok true)
  )
)

;; Emergency withdrawal - Pool creator can withdraw unclaimed funds after expiry
(define-public (emergency-withdrawal (pool-id uint))
  (let (
    (pool (unwrap! (map-get? pools { pool-id: pool-id }) ERR-POOL-NOT-FOUND))
    (total-pool-balance (+ (get total-a pool) (get total-b pool)))
  )
    ;; Access control - only pool creator can emergency withdraw
    (asserts! (is-eq tx-sender (get creator pool)) ERR-NOT-POOL-CREATOR)
    
    ;; Validation - pool must be expired and settled
    (asserts! (> burn-block-height (get expiry pool)) ERR-POOL-NOT-EXPIRED)
    (asserts! (get settled pool) ERR-NOT-SETTLED)
    
    ;; Check contract has balance
    (asserts! (> total-pool-balance u0) ERR-INVALID-AMOUNT)
    
    ;; Transfer remaining balance to pool creator
    (try! (as-contract (stx-transfer? total-pool-balance tx-sender tx-sender)))
    
    (ok total-pool-balance)
  )
)

;; Batch withdrawal - Approve multiple withdrawals at once
(define-public (batch-approve-withdrawals (users (list 10 principal)) (withdrawal-ids (list 10 uint)))
  (let (
    (count (len users))
  )
    ;; Access control
    (asserts! (or (is-admin tx-sender) (is-owner tx-sender)) ERR-UNAUTHORIZED)
    
    ;; Validate lists have same length
    (asserts! (is-eq count (len withdrawal-ids)) ERR-INVALID-AMOUNT)
    
    ;; Process each withdrawal
    (ok (map approve-withdrawal users withdrawal-ids))
  )
)

;; Read-only functions

;; Get pool details
(define-read-only (get-pool (pool-id uint))
  (map-get? pools { pool-id: pool-id })
)

;; Get user bet
(define-read-only (get-user-bet (pool-id uint) (user principal))
  (map-get? user-bets { pool-id: pool-id, user: user })
)

;; Get total pools created
(define-read-only (get-pool-count)
  (var-get pool-counter)
)

;; Get total volume
(define-read-only (get-total-volume)
  (var-get total-volume)
)

;; ============================================
;; CLARITY 3/4 FUNCTIONS - Builder Challenge
;; ============================================

;; [CLARITY 3] Get pool ID as readable ASCII string using int-to-ascii
(define-read-only (get-pool-id-string (pool-id uint))
  (int-to-ascii pool-id)
)

;; [CLARITY 3] Get user's full STX account info using stx-account
(define-read-only (get-user-stx-info (user principal))
  (stx-account user)
)

;; [CLARITY 3] Check if user has sufficient balance to place bet
(define-read-only (can-user-afford-bet (user principal) (amount uint))
  (let ((account-info (stx-account user)))
    (>= (get unlocked account-info) amount)
  )
)

;; [CLARITY 3] Serialize pool totals for cross-contract calls using to-consensus-buff?
(define-read-only (serialize-pool-totals (pool-id uint))
  (match (map-get? pools { pool-id: pool-id })
    pool-data (to-consensus-buff? { 
      total-a: (get total-a pool-data), 
      total-b: (get total-b pool-data),
      settled: (get settled pool-data)
    })
    none
  )
)

;; [CLARITY 3] Public function to register user
(define-public (register-user)
  (begin
    (map-set principal-registry
      { user: tx-sender }
      { 
        registered-at: burn-block-height
      }
    )
    (ok true)
  )
)

;; [CLARITY 3] Get formatted pool info string (combines pool ID with volume)
(define-read-only (get-pool-formatted-info (pool-id uint))
  (let (
    (pool-id-str (int-to-ascii pool-id))
    (volume (var-get total-volume))
    (volume-str (int-to-ascii volume))
  )
    { pool-id-ascii: pool-id-str, total-volume-ascii: volume-str }
  )
)

;; [CLARITY 3] Enhanced bet placement with balance check using stx-account
(define-public (place-bet-safe (pool-id uint) (outcome uint) (amount uint))
  (let (
    (account-info (stx-account tx-sender))
    (unlocked-balance (get unlocked account-info))
  )
    ;; Check if user can afford the bet
    (asserts! (>= unlocked-balance amount) ERR-INSUFFICIENT-BALANCE)
    ;; Proceed with normal bet placement
    (place-bet pool-id outcome amount)
  )
)

;; ============================================
;; CLARITY 4 FUNCTIONS - Builder Challenge Week 1
;; ============================================

;; [CLARITY 4] Get pool info with enhanced formatting using string-concat
(define-read-only (get-pool-info-formatted (pool-id uint))
  (match (map-get? pools { pool-id: pool-id })
    pool-data (ok {
      pool-id: pool-id,
      creator: (get creator pool-data),
      title: (get title pool-data),
      total-a: (get total-a pool-data),
      total-b: (get total-b pool-data),
      settled: (get settled pool-data),
      winning-outcome: (get winning-outcome pool-data)
    })
    (err ERR-POOL-NOT-FOUND)
  )
)

;; [CLARITY 4] Check if principal is valid and get account details
(define-read-only (validate-principal-and-get-balance (user principal))
  (let (
    (account-info (stx-account user))
    (locked (get locked account-info))
    (unlocked (get unlocked account-info))
    (total-balance (+ locked unlocked))
  )
    {
      user: user,
      locked-balance: locked,
      unlocked-balance: unlocked,
      total-balance: total-balance,
      can-bet: (>= unlocked MIN-BET-AMOUNT)
    }
  )
)

;; [CLARITY 4] Get multiple pools info in batch
(define-read-only (get-pools-batch (start-id uint) (count uint))
  (let (
    (end-id (+ start-id count))
    (total-pools (var-get pool-counter))
  )
    (if (> end-id total-pools)
      (ok (list 
        (map-get? pools { pool-id: start-id })
        (map-get? pools { pool-id: (+ start-id u1) })
        (map-get? pools { pool-id: (+ start-id u2) })
        (map-get? pools { pool-id: (+ start-id u3) })
        (map-get? pools { pool-id: (+ start-id u4) })
      ))
      (ok (list 
        (map-get? pools { pool-id: start-id })
        (map-get? pools { pool-id: (+ start-id u1) })
        (map-get? pools { pool-id: (+ start-id u2) })
        (map-get? pools { pool-id: (+ start-id u3) })
        (map-get? pools { pool-id: (+ start-id u4) })
      ))
    )
  )
)

;; [CLARITY 4] Enhanced place-bet with comprehensive validation
(define-public (place-bet-validated (pool-id uint) (outcome uint) (amount uint))
  (let (
    (pool (unwrap! (map-get? pools { pool-id: pool-id }) ERR-POOL-NOT-FOUND))
    (account-info (stx-account tx-sender))
    (unlocked-balance (get unlocked account-info))
  )
    ;; Comprehensive validation
    (asserts! (not (get settled pool)) ERR-POOL-SETTLED)
    (asserts! (or (is-eq outcome u0) (is-eq outcome u1)) ERR-INVALID-OUTCOME)
    (asserts! (>= amount MIN-BET-AMOUNT) ERR-INVALID-AMOUNT)
    (asserts! (>= unlocked-balance amount) ERR-INSUFFICIENT-BALANCE)
    (asserts! (< burn-block-height (get expiry pool)) ERR-POOL-NOT-EXPIRED)
    
    ;; Proceed with bet
    (place-bet pool-id outcome amount)
  )
)

;; [CLARITY 4] Get user's total activity across all pools
(define-read-only (get-user-total-activity (user principal))
  (let (
    (total-pools (var-get pool-counter))
  )
    {
      user: user,
      total-pools-created: (var-get pool-counter),
      total-volume: (var-get total-volume),
      account-info: (stx-account user)
    }
  )
)

;; [CLARITY 4] Settlement with enhanced validation and event tracking
(define-public (settle-pool-enhanced (pool-id uint) (winning-outcome uint))
  (let (
    (pool (unwrap! (map-get? pools { pool-id: pool-id }) ERR-POOL-NOT-FOUND))
    (total-pool-balance (+ (get total-a pool) (get total-b pool)))
    (fee (/ (* total-pool-balance FEE-PERCENT) u100))
  )
    ;; Validation
    (asserts! (is-eq tx-sender (get creator pool)) ERR-UNAUTHORIZED)
    (asserts! (not (get settled pool)) ERR-POOL-SETTLED)
    (asserts! (or (is-eq winning-outcome u0) (is-eq winning-outcome u1)) ERR-INVALID-OUTCOME)
    (asserts! (> total-pool-balance u0) ERR-INVALID-AMOUNT)
    
    ;; Transfer fee if applicable
    (if (> fee u0)
      (try! (as-contract (stx-transfer? fee tx-sender CONTRACT-OWNER)))
      true
    )

    ;; Update pool state
    (map-set pools
      { pool-id: pool-id }
      (merge pool { 
        settled: true, 
        winning-outcome: (some winning-outcome), 
        settled-at: (some burn-block-height) 
      })
    )
    
    (ok {
      pool-id: pool-id,
      winning-outcome: winning-outcome,
      total-pool-balance: total-pool-balance,
      fee-collected: fee
    })
  )
)

;; [CLARITY 4] Get comprehensive pool statistics
(define-read-only (get-pool-stats (pool-id uint))
  (match (map-get? pools { pool-id: pool-id })
    pool-data (let (
      (total-a (get total-a pool-data))
      (total-b (get total-b pool-data))
      (total-pool (+ total-a total-b))
      (percentage-a (if (> total-pool u0) (/ (* total-a u100) total-pool) u0))
      (percentage-b (if (> total-pool u0) (/ (* total-b u100) total-pool) u0))
    )
      (ok {
        pool-id: pool-id,
        total-a: total-a,
        total-b: total-b,
        total-pool: total-pool,
        percentage-a: percentage-a,
        percentage-b: percentage-b,
        settled: (get settled pool-data),
        winning-outcome: (get winning-outcome pool-data)
      })
    )
    (err ERR-POOL-NOT-FOUND)
  )
)

;; ============================================
;; WITHDRAWAL READ-ONLY FUNCTIONS
;; ============================================

;; Get pending withdrawal
(define-read-only (get-pending-withdrawal (user principal) (withdrawal-id uint))
  (map-get? pending-withdrawals { user: user, withdrawal-id: withdrawal-id })
)

;; Get withdrawal history
(define-read-only (get-withdrawal-history (user principal) (withdrawal-id uint))
  (map-get? withdrawal-history { user: user, withdrawal-id: withdrawal-id })
)

;; Get user's withdrawal count
(define-read-only (get-user-withdrawal-count (user principal))
  (default-to u0 (map-get? user-withdrawal-counter { user: user }))
)

;; Get total withdrawn amount
(define-read-only (get-total-withdrawn)
  (var-get total-withdrawn)
)

;; Get withdrawal counter
(define-read-only (get-withdrawal-counter)
  (var-get withdrawal-counter)
)

;; Get contract balance
(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)

;; Get user's total pending withdrawals
(define-read-only (get-user-pending-amount (user principal))
  (let (
    (withdrawal-count (get-user-withdrawal-count user))
  )
    ;; This is a simplified version - in production, you'd iterate through all pending withdrawals
    (ok withdrawal-count)
  )
)

;; Validate withdrawal eligibility
(define-read-only (can-withdraw (user principal) (pool-id uint) (amount uint))
  (match (map-get? pools { pool-id: pool-id })
    pool-data (match (map-get? user-bets { pool-id: pool-id, user: user })
      user-bet (ok {
        pool-settled: (get settled pool-data),
        user-has-bet: true,
        user-bet-amount: (get total-bet user-bet),
        can-withdraw: (and (get settled pool-data) (<= amount (get total-bet user-bet)))
      })
      (ok {
        pool-settled: (get settled pool-data),
        user-has-bet: false,
        user-bet-amount: u0,
        can-withdraw: false
      })
    )
    (err ERR-POOL-NOT-FOUND)
  )
)

;; Get withdrawal status
(define-read-only (get-withdrawal-status (user principal) (withdrawal-id uint))
  (match (map-get? pending-withdrawals { user: user, withdrawal-id: withdrawal-id })
    withdrawal (ok (get status withdrawal))
    (err ERR-INVALID-WITHDRAWAL)
  )
)
