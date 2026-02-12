;; Aegis Withdrawals v3 - Withdrawal Contract
;; Handles normal and emergency withdrawals
;; Part of the Aegis Vault split architecture

;; ============================================
;; CONSTANTS
;; ============================================

(define-constant CONTRACT-OWNER tx-sender)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u5001))
(define-constant ERR-NO-STAKE-FOUND (err u5002))
(define-constant ERR-STAKE-STILL-LOCKED (err u5003))
(define-constant ERR-STAKE-INACTIVE (err u5004))
(define-constant ERR-CONTRACT-PAUSED (err u5005))
(define-constant ERR-STAKING-CONTRACT-NOT-SET (err u5006))
(define-constant ERR-TREASURY-NOT-SET (err u5007))

;; Withdrawal parameters
(define-constant PENALTY-PERCENT u2)         ;; 2% emergency withdrawal penalty
(define-constant PENALTY-DENOMINATOR u100)

;; ============================================
;; DATA VARIABLES
;; ============================================

(define-data-var contract-paused bool false)
(define-data-var staking-contract principal CONTRACT-OWNER)
(define-data-var treasury-contract principal CONTRACT-OWNER)
(define-data-var total-withdrawals uint u0)
(define-data-var total-penalties uint u0)

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

(define-public (set-staking-contract (contract principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set staking-contract contract)
    (ok true)
  )
)

(define-public (set-treasury-contract (contract principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set treasury-contract contract)
    (ok true)
  )
)

;; ============================================
;; PRIVATE HELPERS
;; ============================================

(define-private (calculate-penalty (amount uint))
  (/ (* amount PENALTY-PERCENT) PENALTY-DENOMINATOR)
)

;; ============================================
;; PUBLIC FUNCTIONS
;; ============================================

;; Normal withdrawal (after lock period expires)
(define-public (withdraw (stake-id uint))
  (let
    (
      (staker tx-sender)
      (staking (var-get staking-contract))
      (stake-data (unwrap! (contract-call? .aegis-staking-v2-15 get-stake staker stake-id) ERR-NO-STAKE-FOUND))
      (amount (get amount stake-data))
      (is-unlocked (contract-call? .aegis-staking-v2-15 is-stake-unlocked staker stake-id))
    )
    ;; Validations
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (get is-active stake-data) ERR-STAKE-INACTIVE)
    (asserts! is-unlocked ERR-STAKE-STILL-LOCKED)
    
    ;; Deactivate stake in staking contract
    (try! (contract-call? .aegis-staking-v2-15 deactivate-stake staker stake-id amount))
    
    ;; Transfer full amount back to staker
    (try! (contract-call? .aegis-staking-v2-15 transfer-stx staker amount))
    
    ;; Update stats
    (var-set total-withdrawals (+ (var-get total-withdrawals) u1))
    
    (print { 
      event: "withdraw",
      staker: staker,
      stake-id: stake-id,
      amount: amount,
      penalty: u0
    })
    
    (ok { amount: amount, penalty: u0 })
  )
)

;; Emergency withdrawal (before lock expires, with 2% penalty)
(define-public (emergency-withdraw (stake-id uint))
  (let
    (
      (staker tx-sender)
      (stake-data (unwrap! (contract-call? .aegis-staking-v2-15 get-stake staker stake-id) ERR-NO-STAKE-FOUND))
      (amount (get amount stake-data))
      (penalty (calculate-penalty amount))
      (return-amount (- amount penalty))
      (treasury (var-get treasury-contract))
    )
    ;; Validations
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (get is-active stake-data) ERR-STAKE-INACTIVE)
    
    ;; Deactivate stake in staking contract
    (try! (contract-call? .aegis-staking-v2-15 deactivate-stake staker stake-id amount))
    
    ;; Transfer 98% back to staker
    (try! (contract-call? .aegis-staking-v2-15 transfer-stx staker return-amount))
    
    ;; Transfer 2% penalty to treasury
    (try! (contract-call? .aegis-staking-v2-15 transfer-stx treasury penalty))
    
    ;; Update stats
    (var-set total-withdrawals (+ (var-get total-withdrawals) u1))
    (var-set total-penalties (+ (var-get total-penalties) penalty))
    
    (print { 
      event: "emergency-withdraw",
      staker: staker,
      stake-id: stake-id,
      original-amount: amount,
      penalty: penalty,
      returned: return-amount
    })
    
    (ok { returned: return-amount, penalty: penalty })
  )
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

(define-read-only (get-withdrawal-stats)
  {
    total-withdrawals: (var-get total-withdrawals),
    total-penalties: (var-get total-penalties),
    penalty-percent: PENALTY-PERCENT,
    is-paused: (var-get contract-paused)
  }
)

(define-read-only (get-staking-contract)
  (var-get staking-contract)
)

(define-read-only (get-treasury-contract)
  (var-get treasury-contract)
)

(define-read-only (preview-emergency-withdraw (amount uint))
  {
    penalty: (calculate-penalty amount),
    returned: (- amount (calculate-penalty amount))
  }
)
