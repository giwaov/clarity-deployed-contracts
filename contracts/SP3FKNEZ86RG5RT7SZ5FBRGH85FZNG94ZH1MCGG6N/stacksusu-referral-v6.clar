;; StackSusu Referral v6
;; Enhanced referral program with multi-level rewards and time-limited bonuses

(define-constant CONTRACT-OWNER tx-sender)

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u3000))
(define-constant ERR-ALREADY-REFERRED (err u3001))
(define-constant ERR-SELF-REFERRAL (err u3002))
(define-constant ERR-REFERRER-NOT-FOUND (err u3003))
(define-constant ERR-TRANSFER-FAILED (err u3004))
(define-constant ERR-PAUSED (err u3005))
(define-constant ERR-INVALID-REFERRER (err u3006))
(define-constant ERR-EXPIRED-CODE (err u3007))
(define-constant ERR-INVALID-TIER (err u3008))
(define-constant ERR-MAX-DEPTH-REACHED (err u3009))

;; Multi-level referral settings (NEW in v6)
(define-constant MAX-REFERRAL-DEPTH u3)  ;; Up to 3 levels deep
(define-constant LEVEL-1-PERCENT u50)    ;; 50% to direct referrer
(define-constant LEVEL-2-PERCENT u30)    ;; 30% to L2 referrer
(define-constant LEVEL-3-PERCENT u20)    ;; 20% to L3 referrer

;; Referral relationships
(define-map referrals
  principal  ;; referred member
  {
    referrer: principal,
    referred-at: uint,
    circles-joined: uint,
    total-volume: uint,
    level-2-referrer: (optional principal),  ;; NEW: Track chain
    level-3-referrer: (optional principal)   ;; NEW: Track chain
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
    last-payout: uint,
    level-2-referrals: uint,   ;; NEW: Indirect referrals
    level-3-referrals: uint    ;; NEW: 3rd level referrals
  }
)

;; Pending rewards per referrer
(define-map pending-rewards principal uint)

;; Referral codes (NEW in v6)
(define-map referral-codes
  (string-ascii 20)  ;; code
  {
    owner: principal,
    created-at: uint,
    expires-at: uint,
    uses: uint,
    max-uses: uint,
    bonus-percent: uint  ;; Extra bonus for using this code
  }
)

(define-map member-referral-code
  principal
  (string-ascii 20)
)

;; Time-limited bonus campaigns (NEW in v6)
(define-map bonus-campaigns
  uint  ;; campaign-id
  {
    name: (string-ascii 50),
    multiplier: uint,  ;; 100 = 1x, 150 = 1.5x, 200 = 2x
    start-block: uint,
    end-block: uint,
    active: bool
  }
)

(define-data-var campaign-counter uint u0)
(define-data-var active-campaign-id uint u0)

;; Referral tiers
(define-constant TIER-1-THRESHOLD u5)
(define-constant TIER-2-THRESHOLD u20)
(define-constant TIER-3-THRESHOLD u50)
(define-constant TIER-4-THRESHOLD u100)

(define-constant TIER-0-MULTIPLIER u100)
(define-constant TIER-1-MULTIPLIER u125)
(define-constant TIER-2-MULTIPLIER u150)
(define-constant TIER-3-MULTIPLIER u175)
(define-constant TIER-4-MULTIPLIER u200)

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
;; Referral Code Management (NEW in v6)
;; ============================================

(define-public (create-referral-code 
    (code (string-ascii 20)) 
    (max-uses uint) 
    (valid-blocks uint)
    (bonus-percent uint))
  (let
    (
      (owner tx-sender)
    )
    (asserts! (is-none (map-get? referral-codes code)) ERR-ALREADY-REFERRED)
    (asserts! (<= bonus-percent u50) ERR-INVALID-TIER)  ;; Max 50% bonus
    
    (map-set referral-codes code {
      owner: owner,
      created-at: block-height,
      expires-at: (+ block-height valid-blocks),
      uses: u0,
      max-uses: max-uses,
      bonus-percent: bonus-percent
    })
    
    (map-set member-referral-code owner code)
    
    (ok true)
  )
)

(define-read-only (validate-referral-code (code (string-ascii 20)))
  (match (map-get? referral-codes code)
    code-data
      (and 
        (< block-height (get expires-at code-data))
        (< (get uses code-data) (get max-uses code-data))
      )
    false
  )
)


;; ============================================
;; Referral Registration
;; ============================================

(define-public (register-referral (referrer principal))
  (let
    (
      (new-member tx-sender)
      (existing-referral (map-get? referrals new-member))
      (referrer-referral (map-get? referrals referrer))
      (l2-referrer (match referrer-referral ref (some (get referrer ref)) none))
      (l3-referrer (match referrer-referral ref (get level-2-referrer ref) none))
      (referrer-data (default-to {
        total-referrals: u0,
        active-referrals: u0,
        total-earned: u0,
        pending-rewards: u0,
        last-payout: u0,
        level-2-referrals: u0,
        level-3-referrals: u0
      } (map-get? referrer-stats referrer)))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v6 is-paused)) ERR-PAUSED)
    (asserts! (is-none existing-referral) ERR-ALREADY-REFERRED)
    (asserts! (not (is-eq new-member referrer)) ERR-SELF-REFERRAL)
    
    ;; Record referral with chain
    (map-set referrals new-member {
      referrer: referrer,
      referred-at: block-height,
      circles-joined: u0,
      total-volume: u0,
      level-2-referrer: l2-referrer,
      level-3-referrer: l3-referrer
    })
    
    ;; Update L1 referrer stats
    (map-set referrer-stats referrer
      (merge referrer-data {
        total-referrals: (+ (get total-referrals referrer-data) u1),
        active-referrals: (+ (get active-referrals referrer-data) u1)
      })
    )
    
    ;; Update L2 referrer stats if exists
    (match l2-referrer
      l2
        (let
          (
            (l2-data (default-to {
              total-referrals: u0,
              active-referrals: u0,
              total-earned: u0,
              pending-rewards: u0,
              last-payout: u0,
              level-2-referrals: u0,
              level-3-referrals: u0
            } (map-get? referrer-stats l2)))
          )
          (map-set referrer-stats l2
            (merge l2-data { level-2-referrals: (+ (get level-2-referrals l2-data) u1) }))
        )
      true
    )
    
    ;; Update L3 referrer stats if exists
    (match l3-referrer
      l3
        (let
          (
            (l3-data (default-to {
              total-referrals: u0,
              active-referrals: u0,
              total-earned: u0,
              pending-rewards: u0,
              last-payout: u0,
              level-2-referrals: u0,
              level-3-referrals: u0
            } (map-get? referrer-stats l3)))
          )
          (map-set referrer-stats l3
            (merge l3-data { level-3-referrals: (+ (get level-3-referrals l3-data) u1) }))
        )
      true
    )
    
    ;; Record in reputation
    (try! (contract-call? .stacksusu-reputation-v6 record-referral referrer))
    
    (ok true)
  )
)

(define-public (register-with-code (code (string-ascii 20)))
  (let
    (
      (code-data (unwrap! (map-get? referral-codes code) ERR-REFERRER-NOT-FOUND))
      (referrer (get owner code-data))
    )
    (asserts! (validate-referral-code code) ERR-EXPIRED-CODE)
    
    ;; Update code usage
    (map-set referral-codes code
      (merge code-data { uses: (+ (get uses code-data) u1) }))
    
    ;; Register the referral
    (register-referral referrer)
  )
)


;; ============================================
;; Reward Distribution (Multi-Level)
;; ============================================

(define-public (record-activity (member principal) (amount uint))
  (let
    (
      (referral-data (map-get? referrals member))
      (base-reward-bps (contract-call? .stacksusu-admin-v6 get-referral-fee-bps))
      (campaign-multiplier (get-active-campaign-multiplier))
      (base-reward (/ (* amount base-reward-bps campaign-multiplier) u1000000))
    )
    (asserts! (is-authorized contract-caller) ERR-NOT-AUTHORIZED)
    
    (match referral-data
      ref-data
        (begin
          ;; Update referred member's stats
          (map-set referrals member
            (merge ref-data {
              circles-joined: (+ (get circles-joined ref-data) u1),
              total-volume: (+ (get total-volume ref-data) amount)
            })
          )
          
          ;; Distribute rewards across levels
          (let
            (
              (l1-reward (/ (* base-reward LEVEL-1-PERCENT) u100))
              (l2-reward (/ (* base-reward LEVEL-2-PERCENT) u100))
              (l3-reward (/ (* base-reward LEVEL-3-PERCENT) u100))
            )
            ;; L1 reward
            (credit-referrer (get referrer ref-data) l1-reward)
            
            ;; L2 reward
            (match (get level-2-referrer ref-data)
              l2 (credit-referrer l2 l2-reward)
              true
            )
            
            ;; L3 reward
            (match (get level-3-referrer ref-data)
              l3 (credit-referrer l3 l3-reward)
              true
            )
          )
          
          (ok base-reward)
        )
      (ok u0)
    )
  )
)

(define-private (credit-referrer (referrer principal) (amount uint))
  (let
    (
      (current-pending (default-to u0 (map-get? pending-rewards referrer)))
      (tier-multiplier (get-referrer-tier-multiplier referrer))
      (final-amount (/ (* amount tier-multiplier) u100))
    )
    (map-set pending-rewards referrer (+ current-pending final-amount))
    true
  )
)


;; ============================================
;; Bonus Campaigns (NEW in v6)
;; ============================================

(define-public (create-campaign 
    (name (string-ascii 50))
    (multiplier uint)
    (duration-blocks uint))
  (let
    (
      (campaign-id (+ (var-get campaign-counter) u1))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    (map-set bonus-campaigns campaign-id {
      name: name,
      multiplier: multiplier,
      start-block: block-height,
      end-block: (+ block-height duration-blocks),
      active: true
    })
    
    (var-set campaign-counter campaign-id)
    (var-set active-campaign-id campaign-id)
    
    (ok campaign-id)
  )
)

(define-public (end-campaign (campaign-id uint))
  (let
    (
      (campaign (unwrap! (map-get? bonus-campaigns campaign-id) ERR-NOT-AUTHORIZED))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    (map-set bonus-campaigns campaign-id (merge campaign { active: false }))
    
    (if (is-eq campaign-id (var-get active-campaign-id))
      (var-set active-campaign-id u0)
      true
    )
    
    (ok true)
  )
)

(define-read-only (get-active-campaign-multiplier)
  (let
    (
      (campaign-id (var-get active-campaign-id))
    )
    (if (is-eq campaign-id u0)
      u100  ;; No campaign = 1x
      (match (map-get? bonus-campaigns campaign-id)
        campaign
          (if (and (get active campaign) (< block-height (get end-block campaign)))
            (get multiplier campaign)
            u100)
        u100
      )
    )
  )
)


;; ============================================
;; Claim Rewards
;; ============================================

(define-public (claim-rewards)
  (let
    (
      (claimer tx-sender)
      (pending (default-to u0 (map-get? pending-rewards claimer)))
      (stats (default-to {
        total-referrals: u0,
        active-referrals: u0,
        total-earned: u0,
        pending-rewards: u0,
        last-payout: u0,
        level-2-referrals: u0,
        level-3-referrals: u0
      } (map-get? referrer-stats claimer)))
    )
    (asserts! (> pending u0) ERR-NOT-AUTHORIZED)
    
    ;; Transfer rewards
    (match (as-contract (stx-transfer? pending tx-sender claimer))
      success
        (begin
          (map-set pending-rewards claimer u0)
          (map-set referrer-stats claimer
            (merge stats {
              total-earned: (+ (get total-earned stats) pending),
              pending-rewards: u0,
              last-payout: block-height
            })
          )
          (try! (contract-call? .stacksusu-admin-v6 record-referral-payout pending))
          (ok pending)
        )
      error ERR-TRANSFER-FAILED
    )
  )
)


;; ============================================
;; Read-Only Functions
;; ============================================

(define-read-only (get-referrer (member principal))
  (match (map-get? referrals member)
    ref-data (some (get referrer ref-data))
    none
  )
)

(define-read-only (has-referrer (member principal))
  (is-some (map-get? referrals member))
)

(define-read-only (get-referral-chain (member principal))
  (match (map-get? referrals member)
    ref-data
      (ok (list 
        (get referrer ref-data)
        (default-to (get referrer ref-data) (get level-2-referrer ref-data))
        (default-to (get referrer ref-data) (get level-3-referrer ref-data))
      ))
    (ok (list))
  )
)

(define-read-only (get-referrer-stats (referrer principal))
  (map-get? referrer-stats referrer)
)

(define-read-only (get-pending-rewards (referrer principal))
  (default-to u0 (map-get? pending-rewards referrer))
)

(define-read-only (get-referrer-tier-multiplier (referrer principal))
  (let
    (
      (stats (default-to {
        total-referrals: u0,
        active-referrals: u0,
        total-earned: u0,
        pending-rewards: u0,
        last-payout: u0,
        level-2-referrals: u0,
        level-3-referrals: u0
      } (map-get? referrer-stats referrer)))
      (total (get total-referrals stats))
    )
    (if (>= total TIER-4-THRESHOLD)
      TIER-4-MULTIPLIER
      (if (>= total TIER-3-THRESHOLD)
        TIER-3-MULTIPLIER
        (if (>= total TIER-2-THRESHOLD)
          TIER-2-MULTIPLIER
          (if (>= total TIER-1-THRESHOLD)
            TIER-1-MULTIPLIER
            TIER-0-MULTIPLIER))))
  )
)

(define-read-only (get-referral-code-info (code (string-ascii 20)))
  (map-get? referral-codes code)
)

(define-read-only (get-member-code (member principal))
  (map-get? member-referral-code member)
)

(define-read-only (get-campaign (campaign-id uint))
  (map-get? bonus-campaigns campaign-id)
)

(define-read-only (get-active-campaign)
  (let
    (
      (campaign-id (var-get active-campaign-id))
    )
    (if (> campaign-id u0)
      (map-get? bonus-campaigns campaign-id)
      none
    )
  )
)
