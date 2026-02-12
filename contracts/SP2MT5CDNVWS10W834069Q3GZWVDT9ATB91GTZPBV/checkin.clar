;; Checkin Smart Contract for Stacks Xverse - V3
;; Tracks daily checkins and rewards users
;; Tier 1 (Welcome): Pay 1 STX, Get 1.5 STX
;; Tier 2 (Daily): Pay 0.2 STX, Get 0.25 STX
;; Day cycle: ~144 blocks (approx 24 hours)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-already-checked-in (err u101))
(define-constant err-insufficient-funds (err u102))
(define-constant err-contract-inactive (err u103))

;; Fee and Reward constants
(define-constant fee-initial u1000000)      ;; 1.0 STX
(define-constant reward-initial u1500000)   ;; 1.5 STX
(define-constant fee-daily u200000)         ;; 0.2 STX
(define-constant reward-daily u250000)      ;; 0.25 STX

;; Data Variables
(define-data-var total-fees-collected uint u0)
(define-data-var total-rewards-distributed uint u0)
(define-data-var reward-pool uint u0)
(define-data-var contract-active bool true)

;; Maps
(define-map check-in-status { user: principal, day: uint } bool)
(define-map user-stats principal { total-checkins: uint, last-checkin-day: uint })
(define-map reward-claimed-initial principal bool)

;; Private Functions
(define-private (get-day-index)
  (/ stacks-block-height u144)
)

;; Public Functions

;; Daily Check-In
(define-public (daily-check-in)
  (let
    (
      (caller tx-sender)
      (current-day (get-day-index))
      (already-checked-in (default-to false (map-get? check-in-status { user: caller, day: current-day })))
      (has-claimed-initial (default-to false (map-get? reward-claimed-initial caller)))
    )
    (asserts! (var-get contract-active) err-contract-inactive)
    (asserts! (not already-checked-in) err-already-checked-in)
    
    (if (not has-claimed-initial)
      ;; Tier 1: Initial (1.0 fee -> 1.5 reward)
      (begin
        (asserts! (>= (var-get reward-pool) reward-initial) err-insufficient-funds)
        (try! (stx-transfer? fee-initial caller (as-contract tx-sender)))
        (try! (as-contract (stx-transfer? reward-initial tx-sender caller)))
        
        ;; Update Globals
        (var-set total-fees-collected (+ (var-get total-fees-collected) fee-initial))
        (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) reward-initial))
        (var-set reward-pool (- (var-get reward-pool) reward-initial))
        
        ;; Record Claim
        (map-set reward-claimed-initial caller true)
        
        (print { event: "daily-check-in", type: "initial", user: caller, fee: fee-initial, reward: reward-initial })
      )
      ;; Tier 2: Daily (0.2 fee -> 0.25 reward)
      (begin
        (asserts! (>= (var-get reward-pool) reward-daily) err-insufficient-funds)
        (try! (stx-transfer? fee-daily caller (as-contract tx-sender)))
        (try! (as-contract (stx-transfer? reward-daily tx-sender caller)))
        
        ;; Update Globals
        (var-set total-fees-collected (+ (var-get total-fees-collected) fee-daily))
        (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) reward-daily))
        (var-set reward-pool (- (var-get reward-pool) reward-daily))
        
        (print { event: "daily-check-in", type: "daily", user: caller, fee: fee-daily, reward: reward-daily })
      )
    )

    ;; Updates common to both tiers
    (map-set check-in-status { user: caller, day: current-day } true)
    
    (let ((current-stats (default-to { total-checkins: u0, last-checkin-day: u0 } (map-get? user-stats caller))))
        (map-set user-stats caller {
            total-checkins: (+ (get total-checkins current-stats) u1),
            last-checkin-day: current-day
        })
    )

    (ok true)
  )
)

;; Owner: Fund the reward pool
(define-public (fund-rewards (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set reward-pool (+ (var-get reward-pool) amount))
    (ok true)
  )
)

;; Owner: Withdraw collected fees (or excess funds)
(define-public (withdraw-funds (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (try! (as-contract (stx-transfer? amount tx-sender contract-owner)))
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-fee-summary)
  (ok {
    total-fees-collected: (var-get total-fees-collected),
    total-rewards-distributed: (var-get total-rewards-distributed),
    current-reward-pool: (var-get reward-pool),
    contract-active: (var-get contract-active),
    fee-initial: fee-initial,
    reward-initial: reward-initial,
    fee-daily: fee-daily,
    reward-daily: reward-daily
  })
)

(define-read-only (has-checked-in-today (user principal))
  (ok (default-to false (map-get? check-in-status { user: user, day: (get-day-index) })))
)

(define-read-only (has-claimed-initial-reward (user principal))
  (ok (default-to false (map-get? reward-claimed-initial user)))
)


