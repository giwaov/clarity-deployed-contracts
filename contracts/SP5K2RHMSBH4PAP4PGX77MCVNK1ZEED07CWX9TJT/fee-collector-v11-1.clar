;; Fee Collector Contract - Production Version
;; Dynamic fee tiers based on lock duration

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INVALID_AMOUNT (err u412))

;; Fee Tiers (in basis points - 1 bps = 0.01%)
;; Longer locks = lower fees (incentivize longer locks)
(define-constant FEE_TIER_1_DAYS u7)         ;; Up to 7 days
(define-constant FEE_TIER_1_BPS u100)        ;; 1.0% fee
(define-constant FEE_TIER_2_DAYS u30)        ;; 8-30 days
(define-constant FEE_TIER_2_BPS u75)         ;; 0.75% fee
(define-constant FEE_TIER_3_DAYS u90)        ;; 31-90 days
(define-constant FEE_TIER_3_BPS u50)         ;; 0.5% fee
(define-constant FEE_TIER_4_DAYS u180)       ;; 91-180 days
(define-constant FEE_TIER_4_BPS u25)         ;; 0.25% fee
(define-constant FEE_TIER_5_BPS u10)         ;; 180+ days: 0.1% fee

(define-constant SECONDS_PER_DAY u86400)

;; Storage
(define-data-var total-fees-collected uint u0)
(define-data-var fee-count uint u0)
(define-data-var protocol-treasury principal CONTRACT_OWNER)

;; Fee tracking per tier
(define-map tier-fees uint uint)  ;; tier -> total fees collected

;; Calculate fee based on lock duration
(define-read-only (calculate-fee (amount uint) (lock-duration-seconds uint))
  (let (
    (lock-days (/ lock-duration-seconds SECONDS_PER_DAY))
    (fee-bps (get-fee-tier-bps lock-days))
    (fee-amount (/ (* amount fee-bps) u10000))
  )
    {
      fee-amount: fee-amount,
      fee-bps: fee-bps,
      tier: (get-tier-number lock-days),
      amount-after-fee: (- amount fee-amount)
    }))

;; Get fee tier in basis points
(define-read-only (get-fee-tier-bps (lock-days uint))
  (if (<= lock-days FEE_TIER_1_DAYS)
    FEE_TIER_1_BPS
    (if (<= lock-days FEE_TIER_2_DAYS)
      FEE_TIER_2_BPS
      (if (<= lock-days FEE_TIER_3_DAYS)
        FEE_TIER_3_BPS
        (if (<= lock-days FEE_TIER_4_DAYS)
          FEE_TIER_4_BPS
          FEE_TIER_5_BPS)))))

;; Get tier number (1-5)
(define-read-only (get-tier-number (lock-days uint))
  (if (<= lock-days FEE_TIER_1_DAYS)
    u1
    (if (<= lock-days FEE_TIER_2_DAYS)
      u2
      (if (<= lock-days FEE_TIER_3_DAYS)
        u3
        (if (<= lock-days FEE_TIER_4_DAYS)
          u4
          u5)))))

;; Collect fee (called by exchange contract)
(define-public (collect-fee (amount uint) (lock-duration-seconds uint))
  (let (
    (fee-info (calculate-fee amount lock-duration-seconds))
    (fee-amount (get fee-amount fee-info))
    (tier (get tier fee-info))
    (current-tier-fees (default-to u0 (map-get? tier-fees tier)))
  )
    (asserts! (> fee-amount u0) ERR_INVALID_AMOUNT)
    
    ;; Update storage
    (var-set fee-count (+ (var-get fee-count) u1))
    (var-set total-fees-collected (+ (var-get total-fees-collected) fee-amount))
    (map-set tier-fees tier (+ current-tier-fees fee-amount))
    
    (print {
      event: "fee-collected",
      amount: fee-amount,
      tier: tier,
      fee-bps: (get fee-bps fee-info),
      timestamp: stacks-block-time
    })
    
    (ok fee-amount)))

;; Legacy function for backwards compatibility
(define-public (collect-fee-demo (amount uint))
  (begin
    (var-set fee-count (+ (var-get fee-count) u1))
    (var-set total-fees-collected (+ (var-get total-fees-collected) amount))
    (ok (var-get fee-count))))

;; Get fees collected per tier
(define-read-only (get-tier-fees (tier uint))
  (default-to u0 (map-get? tier-fees tier)))

;; Get all tier statistics
(define-read-only (get-fee-stats)
  {
    total-fees: (var-get total-fees-collected),
    fee-count: (var-get fee-count),
    tier-1-fees: (get-tier-fees u1),
    tier-2-fees: (get-tier-fees u2),
    tier-3-fees: (get-tier-fees u3),
    tier-4-fees: (get-tier-fees u4),
    tier-5-fees: (get-tier-fees u5)
  })

;; Update treasury address (owner only)
(define-public (set-treasury (new-treasury principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set protocol-treasury new-treasury)
    (print { event: "treasury-updated", new-treasury: new-treasury })
    (ok true)))

;; Read-only functions
(define-read-only (get-total-fees)
  (var-get total-fees-collected))

(define-read-only (get-fee-count)
  (var-get fee-count))

(define-read-only (get-treasury)
  (var-get protocol-treasury))

(define-read-only (get-current-time)
  stacks-block-time)

(define-read-only (demo-to-ascii (value uint))
  (to-ascii? value))
