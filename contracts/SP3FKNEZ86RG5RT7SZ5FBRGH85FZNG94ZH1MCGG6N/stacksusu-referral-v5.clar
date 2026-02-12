;; StackSusu Referral v5
;; Referral program for member acquisition and rewards

(define-constant CONTRACT-OWNER tx-sender)

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u3000))
(define-constant ERR-ALREADY-REFERRED (err u3001))
(define-constant ERR-SELF-REFERRAL (err u3002))
(define-constant ERR-REFERRER-NOT-FOUND (err u3003))
(define-constant ERR-TRANSFER-FAILED (err u3004))
(define-constant ERR-PAUSED (err u3005))
(define-constant ERR-INVALID-REFERRER (err u3006))

;; Referral relationships
(define-map referrals
  principal  ;; referred member
  {
    referrer: principal,
    referred-at: uint,
    circles-joined: uint,
    total-volume: uint
  }
)

;; Referrer statistics
(define-map referrer-stats
  principal
  {
    total-referrals: uint,
    active-referrals: uint,
    total-earned: uint,
    pending-rewards: uint,
    last-payout: uint
  }
)

;; Pending rewards per referrer
(define-map pending-rewards principal uint)

;; Referral tiers (bonus multipliers based on referral count)
(define-constant TIER-1-THRESHOLD u5)   ;; 5+ referrals
(define-constant TIER-2-THRESHOLD u20)  ;; 20+ referrals
(define-constant TIER-3-THRESHOLD u50)  ;; 50+ referrals

(define-constant TIER-0-MULTIPLIER u100)  ;; 1x (100%)
(define-constant TIER-1-MULTIPLIER u125)  ;; 1.25x
(define-constant TIER-2-MULTIPLIER u150)  ;; 1.5x
(define-constant TIER-3-MULTIPLIER u200)  ;; 2x

;; Authorized contracts
(define-map authorized-callers principal bool)


;; ============================================
;; Authorization
;; ============================================

(define-read-only (is-authorized (caller principal))
  (or 
    (is-eq caller CONTRACT-OWNER)
    (default-to false (map-get? authorized-callers caller))
  )
)

(define-public (authorize-caller (caller principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-callers caller true))
  )
)

(define-public (revoke-caller (caller principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-delete authorized-callers caller))
  )
)


;; ============================================
;; Referral Registration
;; ============================================

;; Register a referral relationship (called when new member joins with referral code)
(define-public (register-referral (referrer principal))
  (let
    (
      (new-member tx-sender)
      (existing-referral (map-get? referrals new-member))
      (referrer-data (default-to {
        total-referrals: u0,
        active-referrals: u0,
        total-earned: u0,
        pending-rewards: u0,
        last-payout: u0
      } (map-get? referrer-stats referrer)))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v5 is-paused)) ERR-PAUSED)
    (asserts! (is-none existing-referral) ERR-ALREADY-REFERRED)
    (asserts! (not (is-eq new-member referrer)) ERR-SELF-REFERRAL)
    
    ;; Record referral relationship
    (map-set referrals new-member {
      referrer: referrer,
      referred-at: block-height,
      circles-joined: u0,
      total-volume: u0
    })
    
    ;; Update referrer stats
    (map-set referrer-stats referrer
      (merge referrer-data {
        total-referrals: (+ (get total-referrals referrer-data) u1),
        active-referrals: (+ (get active-referrals referrer-data) u1)
      })
    )
    
    (ok true)
  )
)

;; Register referral via authorized contract (for system-initiated referrals)
(define-public (register-referral-internal (new-member principal) (referrer principal))
  (let
    (
      (existing-referral (map-get? referrals new-member))
      (referrer-data (default-to {
        total-referrals: u0,
        active-referrals: u0,
        total-earned: u0,
        pending-rewards: u0,
        last-payout: u0
      } (map-get? referrer-stats referrer)))
    )
    (asserts! (is-authorized contract-caller) ERR-NOT-AUTHORIZED)
    (asserts! (is-none existing-referral) ERR-ALREADY-REFERRED)
    (asserts! (not (is-eq new-member referrer)) ERR-SELF-REFERRAL)
    
    (map-set referrals new-member {
      referrer: referrer,
      referred-at: block-height,
      circles-joined: u0,
      total-volume: u0
    })
    
    (map-set referrer-stats referrer
      (merge referrer-data {
        total-referrals: (+ (get total-referrals referrer-data) u1),
        active-referrals: (+ (get active-referrals referrer-data) u1)
      })
    )
    
    (ok true)
  )
)


;; ============================================
;; Reward Accumulation
;; ============================================

;; Record activity and calculate rewards (called by escrow on deposits)
(define-public (record-activity (member principal) (amount uint))
  (let
    (
      (referral-info (map-get? referrals member))
    )
    (asserts! (is-authorized contract-caller) ERR-NOT-AUTHORIZED)
    
    (match referral-info
      info
        (let
          (
            (referrer (get referrer info))
            (referrer-data (unwrap! (map-get? referrer-stats referrer) ERR-REFERRER-NOT-FOUND))
            (base-reward (contract-call? .stacksusu-admin-v5 calculate-referral-fee amount))
            (tier-multiplier (get-tier-multiplier (get total-referrals referrer-data)))
            (final-reward (/ (* base-reward tier-multiplier) u100))
            (current-pending (default-to u0 (map-get? pending-rewards referrer)))
          )
          ;; Update referred member's stats
          (map-set referrals member
            (merge info {
              circles-joined: (+ (get circles-joined info) u1),
              total-volume: (+ (get total-volume info) amount)
            })
          )
          
          ;; Accumulate pending rewards for referrer
          (map-set pending-rewards referrer (+ current-pending final-reward))
          
          ;; Update referrer pending amount
          (map-set referrer-stats referrer
            (merge referrer-data {
              pending-rewards: (+ (get pending-rewards referrer-data) final-reward)
            })
          )
          
          (ok final-reward)
        )
      (ok u0) ;; No referrer, no reward
    )
  )
)

;; Claim accumulated referral rewards
(define-public (claim-rewards)
  (let
    (
      (caller tx-sender)
      (pending (default-to u0 (map-get? pending-rewards caller)))
      (referrer-data (map-get? referrer-stats caller))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v5 is-paused)) ERR-PAUSED)
    (asserts! (> pending u0) ERR-NOT-AUTHORIZED)
    
    ;; Transfer rewards from contract
    (match (as-contract (stx-transfer? pending tx-sender caller))
      success
        (begin
          ;; Clear pending rewards
          (map-set pending-rewards caller u0)
          
          ;; Update referrer stats
          (match referrer-data
            data
              (map-set referrer-stats caller
                (merge data {
                  total-earned: (+ (get total-earned data) pending),
                  pending-rewards: u0,
                  last-payout: block-height
                })
              )
            true
          )
          
          ;; Record in admin stats
          (try! (contract-call? .stacksusu-admin-v5 record-referral-payment pending))
          
          (ok pending)
        )
      error ERR-TRANSFER-FAILED
    )
  )
)


;; ============================================
;; Tier System
;; ============================================

(define-read-only (get-tier-multiplier (referral-count uint))
  (if (>= referral-count TIER-3-THRESHOLD)
    TIER-3-MULTIPLIER
    (if (>= referral-count TIER-2-THRESHOLD)
      TIER-2-MULTIPLIER
      (if (>= referral-count TIER-1-THRESHOLD)
        TIER-1-MULTIPLIER
        TIER-0-MULTIPLIER
      )
    )
  )
)

(define-read-only (get-referrer-tier (referrer principal))
  (let
    (
      (stats (map-get? referrer-stats referrer))
    )
    (match stats
      s
        (if (>= (get total-referrals s) TIER-3-THRESHOLD)
          u3
          (if (>= (get total-referrals s) TIER-2-THRESHOLD)
            u2
            (if (>= (get total-referrals s) TIER-1-THRESHOLD)
              u1
              u0
            )
          )
        )
      u0
    )
  )
)


;; ============================================
;; Read-only Functions
;; ============================================

(define-read-only (get-referrer (member principal))
  (ok (get referrer (map-get? referrals member)))
)

(define-read-only (get-referral-info (member principal))
  (ok (map-get? referrals member))
)

(define-read-only (get-referrer-stats (referrer principal))
  (ok (default-to {
    total-referrals: u0,
    active-referrals: u0,
    total-earned: u0,
    pending-rewards: u0,
    last-payout: u0
  } (map-get? referrer-stats referrer)))
)

(define-read-only (get-pending-rewards (referrer principal))
  (ok (default-to u0 (map-get? pending-rewards referrer)))
)

(define-read-only (has-referrer (member principal))
  (is-some (map-get? referrals member))
)
