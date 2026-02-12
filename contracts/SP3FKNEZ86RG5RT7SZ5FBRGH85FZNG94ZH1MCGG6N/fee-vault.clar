;; Fee Vault Contract
;; Collect fees, manage revenue sharing, handle withdrawals
;; Built with Clarity 4 features for Stacks Builder Challenge

;; ============================================
;; CONSTANTS & ERRORS
;; ============================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-INSUFFICIENT-BALANCE (err u301))
(define-constant ERR-INVALID-PERCENTAGE (err u302))
(define-constant ERR-INVALID-AMOUNT (err u303))
(define-constant ERR-WITHDRAWAL-LOCKED (err u304))
(define-constant ERR-ALREADY-CLAIMED (err u305))
(define-constant ERR-NOT-STAKEHOLDER (err u306))
(define-constant ERR-ZERO-AMOUNT (err u307))
(define-constant ERR-TRANSFER-FAILED (err u308))

;; Revenue share percentages (basis points - 10000 = 100%)
(define-constant TREASURY-SHARE u7000)      ;; 70% to treasury
(define-constant STAKER-SHARE u2000)        ;; 20% to stakers  
(define-constant REFERRAL-SHARE u1000)      ;; 10% to referrers

(define-constant WITHDRAWAL-COOLDOWN u144)  ;; ~24 hours in blocks
(define-constant MIN-STAKE-AMOUNT u10000000) ;; 10 STX minimum stake

;; ============================================
;; DATA VARIABLES
;; ============================================

(define-data-var total-collected uint u0)
(define-data-var total-distributed uint u0)
(define-data-var treasury-balance uint u0)
(define-data-var staker-pool-balance uint u0)
(define-data-var referral-pool-balance uint u0)
(define-data-var total-staked uint u0)
(define-data-var distribution-epoch uint u0)
(define-data-var last-distribution-block uint u0)

;; ============================================
;; DATA MAPS
;; ============================================

;; Stakeholder information
(define-map stakers
  principal
  {
    staked-amount: uint,
    stake-block: uint,
    last-claim-epoch: uint,
    total-earned: uint,
    pending-rewards: uint
  }
)

;; Referral earnings tracking
(define-map referral-earnings
  principal
  {
    total-referrals: uint,
    total-earned: uint,
    pending-earnings: uint
  }
)

;; Withdrawal requests (for security)
(define-map withdrawal-requests
  principal
  {
    amount: uint,
    request-block: uint,
    is-pending: bool
  }
)

;; Epoch snapshots for reward calculation
(define-map epoch-snapshots
  uint  ;; epoch number
  {
    total-staked: uint,
    rewards-per-token: uint,
    distributed-at: uint
  }
)

;; Fee collection log
(define-map fee-log
  uint  ;; transaction counter
  {
    source: (string-ascii 32),
    amount: uint,
    block: uint
  }
)

(define-data-var fee-log-nonce uint u0)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

;; Get vault balances
(define-read-only (get-balances)
  {
    total-collected: (var-get total-collected),
    total-distributed: (var-get total-distributed),
    treasury: (var-get treasury-balance),
    staker-pool: (var-get staker-pool-balance),
    referral-pool: (var-get referral-pool-balance),
    total-staked: (var-get total-staked)
  }
)

;; Get staker info
(define-read-only (get-staker (staker principal))
  (map-get? stakers staker)
)

;; Get staker's pending rewards
(define-read-only (get-pending-rewards (staker principal))
  (match (map-get? stakers staker)
    staker-data (get pending-rewards staker-data)
    u0
  )
)

;; Calculate reward share for a staker
(define-read-only (calculate-reward-share (staker principal))
  (let
    (
      (staker-data (default-to 
        { staked-amount: u0, stake-block: u0, last-claim-epoch: u0, total-earned: u0, pending-rewards: u0 }
        (map-get? stakers staker)))
      (staker-amount (get staked-amount staker-data))
      (total (var-get total-staked))
      (pool (var-get staker-pool-balance))
    )
    (if (or (is-eq total u0) (is-eq staker-amount u0))
      u0
      (/ (* pool staker-amount) total)
    )
  )
)

;; Get total staked
(define-read-only (get-total-staked)
  (var-get total-staked)
)

;; Get referral earnings
(define-read-only (get-referral-earnings (referrer principal))
  (map-get? referral-earnings referrer)
)

;; Get withdrawal request
(define-read-only (get-withdrawal-request (user principal))
  (map-get? withdrawal-requests user)
)

;; Check if withdrawal is ready
(define-read-only (is-withdrawal-ready (user principal))
  (match (map-get? withdrawal-requests user)
    request (and 
              (get is-pending request)
              (>= stacks-block-height (+ (get request-block request) WITHDRAWAL-COOLDOWN)))
    false
  )
)

;; Get current epoch
(define-read-only (get-current-epoch)
  (var-get distribution-epoch)
)

;; ============================================
;; PRIVATE FUNCTIONS
;; ============================================

;; Split incoming fee into pools
(define-private (split-fee (amount uint))
  (let
    (
      (treasury-amount (/ (* amount TREASURY-SHARE) u10000))
      (staker-amount (/ (* amount STAKER-SHARE) u10000))
      (referral-amount (/ (* amount REFERRAL-SHARE) u10000))
    )
    (var-set treasury-balance (+ (var-get treasury-balance) treasury-amount))
    (var-set staker-pool-balance (+ (var-get staker-pool-balance) staker-amount))
    (var-set referral-pool-balance (+ (var-get referral-pool-balance) referral-amount))
    
    { treasury: treasury-amount, stakers: staker-amount, referrals: referral-amount }
  )
)

;; Log fee collection
(define-private (log-fee (source (string-ascii 32)) (amount uint))
  (let
    (
      (nonce (+ (var-get fee-log-nonce) u1))
    )
    (map-set fee-log nonce
      {
        source: source,
        amount: amount,
        block: stacks-block-height
      }
    )
    (var-set fee-log-nonce nonce)
    nonce
  )
)

;; ============================================
;; PUBLIC FUNCTIONS
;; ============================================

;; Receive fee (called by other contracts or directly)
;; User transfers STX directly - we use contract-call pattern
(define-public (collect-fee (source (string-ascii 32)) (amount uint))
  (let
    (
      (payer tx-sender)
      (vault-addr (as-contract tx-sender))
    )
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    
    ;; Transfer STX from payer to vault
    (try! (stx-transfer? amount payer vault-addr))
    
    ;; Update totals
    (var-set total-collected (+ (var-get total-collected) amount))
    
    ;; Split into pools
    (let
      (
        (split-result (split-fee amount))
        (log-id (log-fee source amount))
      )
      ;; Emit event for chainhook
      (print {
        event: "fee-collected",
        source: source,
        amount: amount,
        treasury-share: (get treasury split-result),
        staker-share: (get stakers split-result),
        referral-share: (get referrals split-result),
        log-id: log-id,
        block: stacks-block-height
      })
      
      (ok split-result)
    )
  )
)

;; Stake STX to earn rewards
(define-public (stake (amount uint))
  (let
    (
      (caller tx-sender)
      (vault-addr (as-contract tx-sender))
      (existing-stake (default-to 
        { staked-amount: u0, stake-block: u0, last-claim-epoch: u0, total-earned: u0, pending-rewards: u0 }
        (map-get? stakers caller)))
    )
    (asserts! (>= amount MIN-STAKE-AMOUNT) ERR-INVALID-AMOUNT)
    
    ;; Transfer STX to vault
    (try! (stx-transfer? amount caller vault-addr))
    
    ;; Update staker record
    (map-set stakers caller
      {
        staked-amount: (+ (get staked-amount existing-stake) amount),
        stake-block: (if (is-eq (get staked-amount existing-stake) u0) 
                        stacks-block-height 
                        (get stake-block existing-stake)),
        last-claim-epoch: (var-get distribution-epoch),
        total-earned: (get total-earned existing-stake),
        pending-rewards: (get pending-rewards existing-stake)
      }
    )
    
    ;; Update total staked
    (var-set total-staked (+ (var-get total-staked) amount))
    
    (print {
      event: "staked",
      staker: caller,
      amount: amount,
      total-staked: (+ (get staked-amount existing-stake) amount),
      block: stacks-block-height
    })
    
    (ok { staked: amount, total: (+ (get staked-amount existing-stake) amount) })
  )
)

;; Request unstake (starts cooldown)
(define-public (request-unstake (amount uint))
  (let
    (
      (caller tx-sender)
      (staker-data (unwrap! (map-get? stakers caller) ERR-NOT-STAKEHOLDER))
    )
    (asserts! (<= amount (get staked-amount staker-data)) ERR-INSUFFICIENT-BALANCE)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    
    ;; Create withdrawal request
    (map-set withdrawal-requests caller
      {
        amount: amount,
        request-block: stacks-block-height,
        is-pending: true
      }
    )
    
    (print {
      event: "unstake-requested",
      staker: caller,
      amount: amount,
      available-at: (+ stacks-block-height WITHDRAWAL-COOLDOWN),
      block: stacks-block-height
    })
    
    (ok { amount: amount, available-at: (+ stacks-block-height WITHDRAWAL-COOLDOWN) })
  )
)

;; Complete unstake after cooldown
(define-public (complete-unstake)
  (let
    (
      (caller tx-sender)
      (request (unwrap! (map-get? withdrawal-requests caller) ERR-WITHDRAWAL-LOCKED))
      (staker-data (unwrap! (map-get? stakers caller) ERR-NOT-STAKEHOLDER))
      (amount (get amount request))
    )
    ;; Check cooldown passed
    (asserts! (get is-pending request) ERR-WITHDRAWAL-LOCKED)
    (asserts! (>= stacks-block-height (+ (get request-block request) WITHDRAWAL-COOLDOWN)) ERR-WITHDRAWAL-LOCKED)
    
    ;; Transfer STX back to user
    (try! (as-contract (stx-transfer? amount tx-sender caller)))
    
    ;; Update staker record
    (map-set stakers caller
      (merge staker-data {
        staked-amount: (- (get staked-amount staker-data) amount)
      })
    )
    
    ;; Clear withdrawal request
    (map-set withdrawal-requests caller
      (merge request { is-pending: false })
    )
    
    ;; Update total staked
    (var-set total-staked (- (var-get total-staked) amount))
    
    (print {
      event: "unstake-completed",
      staker: caller,
      amount: amount,
      remaining-stake: (- (get staked-amount staker-data) amount),
      block: stacks-block-height
    })
    
    (ok amount)
  )
)

;; Claim staking rewards
(define-public (claim-rewards)
  (let
    (
      (caller tx-sender)
      (staker-data (unwrap! (map-get? stakers caller) ERR-NOT-STAKEHOLDER))
      (reward-amount (calculate-reward-share caller))
    )
    (asserts! (> reward-amount u0) ERR-ZERO-AMOUNT)
    
    ;; Transfer rewards
    (try! (as-contract (stx-transfer? reward-amount tx-sender caller)))
    
    ;; Update staker record
    (map-set stakers caller
      (merge staker-data {
        last-claim-epoch: (var-get distribution-epoch),
        total-earned: (+ (get total-earned staker-data) reward-amount),
        pending-rewards: u0
      })
    )
    
    ;; Update pool balance
    (var-set staker-pool-balance (- (var-get staker-pool-balance) reward-amount))
    (var-set total-distributed (+ (var-get total-distributed) reward-amount))
    
    (print {
      event: "rewards-claimed",
      staker: caller,
      amount: reward-amount,
      total-earned: (+ (get total-earned staker-data) reward-amount),
      block: stacks-block-height
    })
    
    (ok reward-amount)
  )
)

;; Credit referral earnings (called by registry)
(define-public (credit-referral (referrer principal) (amount uint))
  (let
    (
      (existing (default-to 
        { total-referrals: u0, total-earned: u0, pending-earnings: u0 }
        (map-get? referral-earnings referrer)))
    )
    ;; Only authorized contracts can credit referrals
    (asserts! (or (is-eq contract-caller .stackpulse-registry) (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)
    
    (map-set referral-earnings referrer
      {
        total-referrals: (+ (get total-referrals existing) u1),
        total-earned: (get total-earned existing),
        pending-earnings: (+ (get pending-earnings existing) amount)
      }
    )
    
    (print {
      event: "referral-credited",
      referrer: referrer,
      amount: amount,
      block: stacks-block-height
    })
    
    (ok true)
  )
)

;; Claim referral earnings
(define-public (claim-referral-earnings)
  (let
    (
      (caller tx-sender)
      (earnings (unwrap! (map-get? referral-earnings caller) ERR-NOT-STAKEHOLDER))
      (pending (get pending-earnings earnings))
    )
    (asserts! (> pending u0) ERR-ZERO-AMOUNT)
    (asserts! (<= pending (var-get referral-pool-balance)) ERR-INSUFFICIENT-BALANCE)
    
    ;; Transfer earnings
    (try! (as-contract (stx-transfer? pending tx-sender caller)))
    
    ;; Update record
    (map-set referral-earnings caller
      (merge earnings {
        total-earned: (+ (get total-earned earnings) pending),
        pending-earnings: u0
      })
    )
    
    ;; Update pool
    (var-set referral-pool-balance (- (var-get referral-pool-balance) pending))
    (var-set total-distributed (+ (var-get total-distributed) pending))
    
    (print {
      event: "referral-earnings-claimed",
      referrer: caller,
      amount: pending,
      block: stacks-block-height
    })
    
    (ok pending)
  )
)

;; Withdraw treasury funds (admin only)
(define-public (withdraw-treasury (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= amount (var-get treasury-balance)) ERR-INSUFFICIENT-BALANCE)
    
    (try! (as-contract (stx-transfer? amount tx-sender recipient)))
    
    (var-set treasury-balance (- (var-get treasury-balance) amount))
    (var-set total-distributed (+ (var-get total-distributed) amount))
    
    (print {
      event: "treasury-withdrawn",
      amount: amount,
      recipient: recipient,
      remaining: (- (var-get treasury-balance) amount),
      block: stacks-block-height
    })
    
    (ok amount)
  )
)

;; Trigger new distribution epoch (admin only)
(define-public (trigger-distribution)
  (let
    (
      (new-epoch (+ (var-get distribution-epoch) u1))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    ;; Create epoch snapshot
    (map-set epoch-snapshots new-epoch
      {
        total-staked: (var-get total-staked),
        rewards-per-token: (if (> (var-get total-staked) u0)
                            (/ (var-get staker-pool-balance) (var-get total-staked))
                            u0),
        distributed-at: stacks-block-height
      }
    )
    
    (var-set distribution-epoch new-epoch)
    (var-set last-distribution-block stacks-block-height)
    
    (print {
      event: "distribution-triggered",
      epoch: new-epoch,
      total-staked: (var-get total-staked),
      pool-balance: (var-get staker-pool-balance),
      block: stacks-block-height
    })
    
    (ok new-epoch)
  )
)
