;; Aegis Staking v3 - Core Staking Contract
;; Handles stake deposits and position tracking only
;; Part of the Aegis Vault split architecture

;; ============================================
;; CONSTANTS
;; ============================================

(define-constant CONTRACT-OWNER tx-sender)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u4001))
(define-constant ERR-INVALID-AMOUNT (err u4002))
(define-constant ERR-INVALID-LOCK-PERIOD (err u4003))
(define-constant ERR-CONTRACT-PAUSED (err u4004))
(define-constant ERR-MAX-STAKES-REACHED (err u4005))

;; Staking parameters
(define-constant MIN-STAKE u10000)           ;; 0.01 STX minimum
(define-constant MAX-STAKES-PER-USER u20)    ;; Max 20 concurrent stakes
(define-constant BLOCKS-PER-DAY u144)        ;; ~144 blocks per day

;; Lock periods (in days, converted to blocks on-chain)
(define-constant LOCK-3-DAYS u3)
(define-constant LOCK-7-DAYS u7)
(define-constant LOCK-30-DAYS u30)

;; Bonus multipliers (basis points, 10000 = 1x)
(define-constant BONUS-3-DAYS u10000)        ;; 1.0x
(define-constant BONUS-7-DAYS u12000)        ;; 1.2x  
(define-constant BONUS-30-DAYS u15000)       ;; 1.5x

;; ============================================
;; DATA VARIABLES
;; ============================================

(define-data-var contract-paused bool false)
(define-data-var total-staked uint u0)
(define-data-var total-stakers uint u0)
(define-data-var stake-counter uint u0)
(define-data-var withdrawals-contract principal CONTRACT-OWNER)
(define-data-var rewards-contract principal CONTRACT-OWNER)

;; ============================================
;; DATA MAPS
;; ============================================

;; Individual stake positions
(define-map stakes 
  { staker: principal, stake-id: uint }
  {
    amount: uint,
    start-block: uint,
    lock-blocks: uint,
    lock-period-type: uint,
    bonus-multiplier: uint,
    is-active: bool,
    total-claimed: uint
  }
)

;; Track user's stake IDs
(define-map user-stake-ids principal (list 20 uint))

;; Track user's total staked
(define-map user-total-staked principal uint)

;; Authorized contracts that can update stake data
(define-map authorized-contracts principal bool)

;; ============================================
;; AUTHORIZATION
;; ============================================

(define-private (is-authorized)
  (or 
    (is-eq tx-sender CONTRACT-OWNER)
    (default-to false (map-get? authorized-contracts contract-caller))
  )
)

;; ============================================
;; ADMIN FUNCTIONS
;; ============================================

(define-public (set-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set contract-paused paused)
    (ok true)
  )
)

(define-public (authorize-contract (contract principal) (authorized bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set authorized-contracts contract authorized)
    (ok true)
  )
)

(define-public (set-withdrawals-contract (contract principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set withdrawals-contract contract)
    (map-set authorized-contracts contract true)
    (ok true)
  )
)

(define-public (set-rewards-contract (contract principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set rewards-contract contract)
    (map-set authorized-contracts contract true)
    (ok true)
  )
)

;; ============================================
;; PRIVATE HELPERS
;; ============================================

(define-private (get-lock-blocks (lock-period uint))
  (* lock-period BLOCKS-PER-DAY)
)

(define-private (get-bonus-multiplier (lock-period uint))
  (if (is-eq lock-period LOCK-30-DAYS)
    BONUS-30-DAYS
    (if (is-eq lock-period LOCK-7-DAYS)
      BONUS-7-DAYS
      BONUS-3-DAYS
    )
  )
)

(define-private (is-valid-lock-period (lock-period uint))
  (or 
    (is-eq lock-period LOCK-3-DAYS)
    (or 
      (is-eq lock-period LOCK-7-DAYS)
      (is-eq lock-period LOCK-30-DAYS)
    )
  )
)

;; ============================================
;; PUBLIC FUNCTIONS
;; ============================================

;; Stake STX with a lock period
(define-public (stake (amount uint) (lock-period uint))
  (let
    (
      (staker tx-sender)
      (current-stakes (default-to (list) (map-get? user-stake-ids staker)))
      (new-stake-id (+ (var-get stake-counter) u1))
      (lock-blocks (get-lock-blocks lock-period))
      (bonus (get-bonus-multiplier lock-period))
    )
    ;; Validations
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (>= amount MIN-STAKE) ERR-INVALID-AMOUNT)
    (asserts! (is-valid-lock-period lock-period) ERR-INVALID-LOCK-PERIOD)
    (asserts! (< (len current-stakes) MAX-STAKES-PER-USER) ERR-MAX-STAKES-REACHED)
    
    ;; Transfer STX to this contract
    (try! (stx-transfer? amount staker (as-contract tx-sender)))
    
    ;; Create stake record
    (map-set stakes
      { staker: staker, stake-id: new-stake-id }
      {
        amount: amount,
        start-block: block-height,
        lock-blocks: lock-blocks,
        lock-period-type: lock-period,
        bonus-multiplier: bonus,
        is-active: true,
        total-claimed: u0
      }
    )
    
    ;; Update user's stake list
    (map-set user-stake-ids staker 
      (unwrap! (as-max-len? (append current-stakes new-stake-id) u20) ERR-MAX-STAKES-REACHED))
    
    ;; Update totals
    (map-set user-total-staked staker 
      (+ (default-to u0 (map-get? user-total-staked staker)) amount))
    (var-set total-staked (+ (var-get total-staked) amount))
    (var-set stake-counter new-stake-id)
    
    ;; Increment stakers if first stake
    (if (is-eq (len current-stakes) u0)
      (var-set total-stakers (+ (var-get total-stakers) u1))
      true
    )
    
    (print { 
      event: "stake",
      staker: staker,
      stake-id: new-stake-id,
      amount: amount,
      lock-period: lock-period,
      lock-blocks: lock-blocks,
      unlock-block: (+ block-height lock-blocks)
    })
    
    (ok new-stake-id)
  )
)

;; Called by withdrawals contract to deactivate stake
(define-public (deactivate-stake (staker principal) (stake-id uint) (amount uint))
  (let
    (
      (stake-data (unwrap! (map-get? stakes { staker: staker, stake-id: stake-id }) ERR-INVALID-AMOUNT))
    )
    (asserts! (is-authorized) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active stake-data) ERR-INVALID-AMOUNT)
    
    ;; Deactivate stake
    (map-set stakes
      { staker: staker, stake-id: stake-id }
      (merge stake-data { is-active: false })
    )
    
    ;; Update totals
    (map-set user-total-staked staker 
      (- (default-to u0 (map-get? user-total-staked staker)) amount))
    (var-set total-staked (- (var-get total-staked) amount))
    
    (ok true)
  )
)

;; Called by rewards contract to update claimed amount
(define-public (update-claimed (staker principal) (stake-id uint) (claimed-amount uint))
  (let
    (
      (stake-data (unwrap! (map-get? stakes { staker: staker, stake-id: stake-id }) ERR-INVALID-AMOUNT))
    )
    (asserts! (is-authorized) ERR-NOT-AUTHORIZED)
    
    (map-set stakes
      { staker: staker, stake-id: stake-id }
      (merge stake-data { total-claimed: (+ (get total-claimed stake-data) claimed-amount) })
    )
    
    (ok true)
  )
)

;; Transfer STX out (called by withdrawals contract)
(define-public (transfer-stx (recipient principal) (amount uint))
  (begin
    (asserts! (is-authorized) ERR-NOT-AUTHORIZED)
    (as-contract (stx-transfer? amount tx-sender recipient))
  )
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

(define-read-only (get-stake (staker principal) (stake-id uint))
  (map-get? stakes { staker: staker, stake-id: stake-id })
)

(define-read-only (get-user-stake-ids (user principal))
  (default-to (list) (map-get? user-stake-ids user))
)

(define-read-only (get-user-total-staked (user principal))
  (default-to u0 (map-get? user-total-staked user))
)

(define-read-only (is-stake-unlocked (staker principal) (stake-id uint))
  (match (map-get? stakes { staker: staker, stake-id: stake-id })
    stake-data
      (>= block-height (+ (get start-block stake-data) (get lock-blocks stake-data)))
    false
  )
)

(define-read-only (get-unlock-block (staker principal) (stake-id uint))
  (match (map-get? stakes { staker: staker, stake-id: stake-id })
    stake-data
      (ok (+ (get start-block stake-data) (get lock-blocks stake-data)))
    (err u0)
  )
)

(define-read-only (get-vault-stats)
  {
    total-staked: (var-get total-staked),
    total-stakers: (var-get total-stakers),
    stake-counter: (var-get stake-counter),
    is-paused: (var-get contract-paused),
    vault-balance: (stx-get-balance (as-contract tx-sender))
  }
)

(define-read-only (is-contract-authorized (contract principal))
  (default-to false (map-get? authorized-contracts contract))
)

(define-read-only (get-withdrawals-contract)
  (var-get withdrawals-contract)
)

(define-read-only (get-rewards-contract)
  (var-get rewards-contract)
)
