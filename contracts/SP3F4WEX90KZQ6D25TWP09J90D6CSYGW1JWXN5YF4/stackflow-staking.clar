;; StackFlow Staking Contract
;; Enables FLOW token staking for fee discounts and governance power
;; Tier system: Ripple (1K), Wave (5K), Current (20K), Ocean (100K)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-found (err u201))
(define-constant err-insufficient-balance (err u202))
(define-constant err-invalid-amount (err u203))
(define-constant err-paused (err u204))
(define-constant err-insufficient-stake (err u205))
(define-constant err-transfer-failed (err u206))

;; Token reference (update after deploying FLOW token)
(define-constant flow-token 'SP3F4WEX90KZQ6D25TWP09J90D6CSYGW1JWXN5YF4.stackflow-flow-token)

;; Tier thresholds (with 6 decimals)
(define-constant ripple-threshold u1000000000) ;; 1,000 FLOW
(define-constant wave-threshold u5000000000) ;; 5,000 FLOW
(define-constant current-threshold u20000000000) ;; 20,000 FLOW
(define-constant ocean-threshold u100000000000) ;; 100,000 FLOW

;; Fee discount percentages (basis points, 100 = 1%)
(define-constant ripple-discount u1000) ;; 10%
(define-constant wave-discount u2500) ;; 25%
(define-constant current-discount u5000) ;; 50%
(define-constant ocean-discount u7500) ;; 75%

;; State
(define-data-var paused bool false)
(define-data-var total-staked uint u0)
(define-data-var total-stakers uint u0)

;; Staking data
(define-map stakes principal {
  amount: uint,
  staked-at: uint,
  last-claim: uint
})

;; Track cumulative rewards (future use)
(define-map cumulative-rewards principal uint)

;; Read-only: Get user's stake
(define-read-only (get-stake (user principal))
  (map-get? stakes user))

;; Read-only: Calculate user's tier
(define-read-only (get-user-tier (user principal))
  (let ((stake-data (get-stake user)))
    (match stake-data
      data
        (let ((amount (get amount data)))
          (if (>= amount ocean-threshold)
            (ok "OCEAN")
            (if (>= amount current-threshold)
              (ok "CURRENT")
              (if (>= amount wave-threshold)
                (ok "WAVE")
                (if (>= amount ripple-threshold)
                  (ok "RIPPLE")
                  (ok "NONE"))))))
      (ok "NONE"))))

;; Read-only: Get fee discount for user (in basis points)
(define-read-only (get-fee-discount (user principal))
  (let ((stake-data (get-stake user)))
    (match stake-data
      data
        (let ((amount (get amount data)))
          (ok (if (>= amount ocean-threshold)
            ocean-discount
            (if (>= amount current-threshold)
              current-discount
              (if (>= amount wave-threshold)
                wave-discount
                (if (>= amount ripple-threshold)
                  ripple-discount
                  u0))))))
      (ok u0))))

;; Read-only: Calculate discounted fee
(define-read-only (calculate-discounted-fee (user principal) (original-fee uint))
  (let ((discount-bps (unwrap-panic (get-fee-discount user))))
    (let ((discount-amount (/ (* original-fee discount-bps) u10000)))
      (ok (- original-fee discount-amount)))))

;; Stake FLOW tokens
(define-public (stake (amount uint))
  (let (
    (sender tx-sender)
    (current-stake (default-to {amount: u0, staked-at: u0, last-claim: u0} (get-stake sender)))
  )
    (asserts! (not (var-get paused)) err-paused)
    (asserts! (> amount u0) err-invalid-amount)
    
    ;; Transfer FLOW from user to this contract
    (match (contract-call? flow-token transfer amount sender (as-contract tx-sender) none)
      success
        (let (
          (new-amount (+ (get amount current-stake) amount))
          (is-new-staker (is-eq (get amount current-stake) u0))
        )
          ;; Update stake
          (map-set stakes sender {
            amount: new-amount,
            staked-at: (if is-new-staker stacks-block-height (get staked-at current-stake)),
            last-claim: stacks-block-height
          })
          
          ;; Update totals
          (var-set total-staked (+ (var-get total-staked) amount))
          (if is-new-staker
            (var-set total-stakers (+ (var-get total-stakers) u1))
            true)
          
          (print {
            event: "stake",
            user: sender,
            amount: amount,
            total-staked: new-amount,
            tier: (unwrap-panic (get-user-tier sender))
          })
          
          (ok true))
      error err-transfer-failed)))

;; Unstake FLOW tokens
(define-public (unstake (amount uint))
  (let (
    (sender tx-sender)
    (current-stake (unwrap! (get-stake sender) err-not-found))
  )
    (asserts! (not (var-get paused)) err-paused)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= (get amount current-stake) amount) err-insufficient-stake)
    
    ;; Transfer FLOW from contract to user
    (try! (as-contract (contract-call? flow-token transfer amount tx-sender sender none)))
    
    (let ((new-amount (- (get amount current-stake) amount)))
      ;; Update or remove stake
      (if (is-eq new-amount u0)
        (begin
          (map-delete stakes sender)
          (var-set total-stakers (- (var-get total-stakers) u1)))
        (map-set stakes sender (merge current-stake {amount: new-amount})))
      
      ;; Update total
      (var-set total-staked (- (var-get total-staked) amount))
      
      (print {
        event: "unstake",
        user: sender,
        amount: amount,
        remaining: new-amount,
        tier: (unwrap-panic (get-user-tier sender))
      })
      
      (ok true))))

;; Emergency unstake all (no rewards)
(define-public (emergency-unstake)
  (let (
    (sender tx-sender)
    (current-stake (unwrap! (get-stake sender) err-not-found))
    (amount (get amount current-stake))
  )
    ;; Transfer FLOW from contract to user
    (try! (as-contract (contract-call? flow-token transfer amount tx-sender sender none)))
    
    ;; Remove stake
    (map-delete stakes sender)
    
    ;; Update totals
    (var-set total-staked (- (var-get total-staked) amount))
    (var-set total-stakers (- (var-get total-stakers) u1))
    
    (print {
      event: "emergency-unstake",
      user: sender,
      amount: amount
    })
    
    (ok true)))

;; Read-only utilities

(define-read-only (get-stats)
  (ok {
    total-staked: (var-get total-staked),
    total-stakers: (var-get total-stakers),
    paused: (var-get paused)
  }))

(define-read-only (get-tier-thresholds)
  (ok {
    ripple: ripple-threshold,
    wave: wave-threshold,
    current: current-threshold,
    ocean: ocean-threshold
  }))

(define-read-only (get-tier-discounts)
  (ok {
    ripple: ripple-discount,
    wave: wave-discount,
    current: current-discount,
    ocean: ocean-discount
  }))

;; Admin functions

(define-public (pause-staking)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set paused true)
    (print {event: "staking-paused"})
    (ok true)))

(define-public (unpause-staking)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set paused false)
    (print {event: "staking-unpaused"})
    (ok true)))
