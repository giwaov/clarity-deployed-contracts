;; StackSusu Reputation v6
;; Enhanced reputation with decay, badges, and cross-circle scoring

(define-constant CONTRACT-OWNER tx-sender)

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u2000))
(define-constant ERR-MEMBER-NOT-FOUND (err u2001))
(define-constant ERR-INVALID-SCORE (err u2002))
(define-constant ERR-ALREADY-RECORDED (err u2003))
(define-constant ERR-BADGE-NOT-FOUND (err u2004))
(define-constant ERR-ALREADY-HAS-BADGE (err u2005))

;; Reputation score weights
(define-constant COMPLETION-WEIGHT u100)
(define-constant DEFAULT-PENALTY u200)
(define-constant ON-TIME-BONUS u20)
(define-constant VOLUME-WEIGHT u1)
(define-constant REFERRAL-BONUS u50)

;; Decay settings (reputation decays if inactive)
(define-constant DECAY-PERIOD-BLOCKS u4320)  ;; ~30 days
(define-constant DECAY-PERCENT u5)           ;; 5% decay per period

;; Starting reputation score
(define-constant BASE-SCORE u500)
(define-constant MAX-SCORE u10000)
(define-constant MIN-SCORE u0)

;; Badge types
(define-constant BADGE-FIRST-CIRCLE u1)
(define-constant BADGE-5-CIRCLES u2)
(define-constant BADGE-10-CIRCLES u3)
(define-constant BADGE-PERFECT-RECORD u4)
(define-constant BADGE-HIGH-VOLUME u5)
(define-constant BADGE-TOP-REFERRER u6)
(define-constant BADGE-VETERAN u7)
(define-constant BADGE-EARLY-ADOPTER u8)

;; Member reputation data
(define-map member-reputation
  principal
  {
    circles-completed: uint,
    circles-defaulted: uint,
    on-time-payments: uint,
    late-payments: uint,
    total-volume: uint,
    total-payouts-received: uint,
    score: uint,
    last-activity: uint,
    joined-at: uint,
    streak: uint,                    ;; NEW: Consecutive on-time payments
    longest-streak: uint,            ;; NEW: Best streak ever
    referral-count: uint,            ;; NEW: Number of referrals made
    badges-earned: uint              ;; NEW: Number of badges
  }
)

;; Badge tracking
(define-map member-badges
  { member: principal, badge-type: uint }
  { earned-at: uint, circle-id: uint }
)

;; Circle-specific member records
(define-map circle-member-record
  { circle-id: uint, member: principal }
  { completed: bool, defaulted: bool, recorded-at: uint, on-time-count: uint, late-count: uint }
)

;; Cross-circle reputation (aggregated scores per category)
(define-map category-reputation
  { member: principal, category: (string-ascii 20) }
  { score: uint, circles-count: uint }
)

;; Tier thresholds
(define-map reputation-tiers
  uint
  { name: (string-ascii 20), min-score: uint, benefits: (string-ascii 100) }
)

;; Authorized contracts
(define-map authorized-updaters principal bool)


;; ============================================
;; Helper Functions
;; ============================================

;; Minimum of two values
(define-private (get-min (a uint) (b uint))
  (if (<= a b) a b)
)

;; Maximum of two values
(define-private (get-max (a uint) (b uint))
  (if (>= a b) a b)
)


;; ============================================
;; Initialization
;; ============================================

;; Initialize reputation tiers
(map-set reputation-tiers u1 { name: "Bronze", min-score: u0, benefits: "Basic access" })
(map-set reputation-tiers u2 { name: "Silver", min-score: u300, benefits: "Reduced fees 10%" })
(map-set reputation-tiers u3 { name: "Gold", min-score: u600, benefits: "Reduced fees 20%, priority support" })
(map-set reputation-tiers u4 { name: "Platinum", min-score: u1000, benefits: "Reduced fees 30%, early access" })
(map-set reputation-tiers u5 { name: "Diamond", min-score: u2000, benefits: "Reduced fees 50%, VIP benefits" })


;; ============================================
;; Authorization
;; ============================================

(define-read-only (is-authorized (caller principal))
  (or 
    (is-eq caller CONTRACT-OWNER)
    (default-to false (map-get? authorized-updaters caller))
  )
)

(define-public (authorize-updater (updater principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-updaters updater true))
  )
)

(define-public (revoke-updater (updater principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-delete authorized-updaters updater))
  )
)


;; ============================================
;; Member Initialization
;; ============================================

(define-public (initialize-member (member principal))
  (begin
    (asserts! (is-authorized contract-caller) ERR-NOT-AUTHORIZED)
    (if (is-none (map-get? member-reputation member))
      (begin
        (map-set member-reputation member {
          circles-completed: u0,
          circles-defaulted: u0,
          on-time-payments: u0,
          late-payments: u0,
          total-volume: u0,
          total-payouts-received: u0,
          score: BASE-SCORE,
          last-activity: block-height,
          joined-at: block-height,
          streak: u0,
          longest-streak: u0,
          referral-count: u0,
          badges-earned: u0
        })
        ;; Award early adopter badge if applicable
        (if (< block-height u100000)  ;; Early blocks
          (award-badge-internal member BADGE-EARLY-ADOPTER u0)
          true
        )
        (ok true)
      )
      (ok true)
    )
  )
)


;; ============================================
;; Record Activity
;; ============================================

(define-public (record-contribution (member principal) (amount uint))
  (let
    (
      (current-rep (unwrap! (map-get? member-reputation member) ERR-MEMBER-NOT-FOUND))
      (volume-bonus (/ amount u1000000))  ;; 1 point per STX
    )
    (asserts! (is-authorized contract-caller) ERR-NOT-AUTHORIZED)
    
    (map-set member-reputation member
      (merge current-rep {
        total-volume: (+ (get total-volume current-rep) amount),
        score: (get-min MAX-SCORE (+ (get score current-rep) volume-bonus)),
        last-activity: block-height
      })
    )
    
    ;; Check for high volume badge
    (if (and (< (get total-volume current-rep) u100000000000)
             (>= (+ (get total-volume current-rep) amount) u100000000000))
      (award-badge-internal member BADGE-HIGH-VOLUME u0)
      true
    )
    
    (ok true)
  )
)

(define-public (record-completion (member principal) (circle-id uint) (payout-amount uint) (was-on-time bool))
  (let
    (
      (existing-record (map-get? circle-member-record { circle-id: circle-id, member: member }))
      (current-rep (unwrap! (map-get? member-reputation member) ERR-MEMBER-NOT-FOUND))
      (completion-bonus COMPLETION-WEIGHT)
      (time-bonus (if was-on-time ON-TIME-BONUS u0))
      (new-streak (if was-on-time (+ (get streak current-rep) u1) u0))
      (new-longest (if (> new-streak (get longest-streak current-rep)) new-streak (get longest-streak current-rep)))
      (streak-bonus (if (> new-streak u5) (* (- new-streak u5) u5) u0))  ;; Bonus for streaks > 5
      (new-score (calculate-new-score (get score current-rep) (+ completion-bonus time-bonus streak-bonus) true))
      (new-completed (+ (get circles-completed current-rep) u1))
    )
    (asserts! (is-authorized contract-caller) ERR-NOT-AUTHORIZED)
    (asserts! (or (is-none existing-record) 
                  (not (get completed (unwrap-panic existing-record)))) 
              ERR-ALREADY-RECORDED)
    
    ;; Update circle record
    (map-set circle-member-record 
      { circle-id: circle-id, member: member }
      { completed: true, defaulted: false, recorded-at: block-height,
        on-time-count: (if was-on-time u1 u0), late-count: (if was-on-time u0 u1) }
    )
    
    ;; Update reputation
    (map-set member-reputation member
      (merge current-rep {
        circles-completed: new-completed,
        on-time-payments: (if was-on-time 
                            (+ (get on-time-payments current-rep) u1)
                            (get on-time-payments current-rep)),
        late-payments: (if was-on-time
                         (get late-payments current-rep)
                         (+ (get late-payments current-rep) u1)),
        total-payouts-received: (+ (get total-payouts-received current-rep) payout-amount),
        score: new-score,
        last-activity: block-height,
        streak: new-streak,
        longest-streak: new-longest
      })
    )
    
    ;; Check for badges
    (check-and-award-badges member new-completed (get circles-defaulted current-rep) new-longest)
    
    (ok true)
  )
)

(define-public (record-default (member principal) (circle-id uint))
  (let
    (
      (existing-record (map-get? circle-member-record { circle-id: circle-id, member: member }))
      (current-rep (unwrap! (map-get? member-reputation member) ERR-MEMBER-NOT-FOUND))
      (new-score (calculate-new-score (get score current-rep) DEFAULT-PENALTY false))
    )
    (asserts! (is-authorized contract-caller) ERR-NOT-AUTHORIZED)
    (asserts! (or (is-none existing-record)
                  (not (get defaulted (unwrap-panic existing-record))))
              ERR-ALREADY-RECORDED)
    
    (map-set circle-member-record
      { circle-id: circle-id, member: member }
      { completed: false, defaulted: true, recorded-at: block-height, on-time-count: u0, late-count: u0 }
    )
    
    (map-set member-reputation member
      (merge current-rep {
        circles-defaulted: (+ (get circles-defaulted current-rep) u1),
        score: new-score,
        last-activity: block-height,
        streak: u0  ;; Reset streak on default
      })
    )
    
    (ok true)
  )
)

;; Generic action recording for other contracts
(define-public (record-action (member principal) (action-type uint))
  (let
    (
      (current-rep (default-to {
        circles-completed: u0,
        circles-defaulted: u0,
        on-time-payments: u0,
        late-payments: u0,
        total-volume: u0,
        total-payouts-received: u0,
        score: BASE-SCORE,
        last-activity: u0,
        joined-at: block-height,
        streak: u0,
        longest-streak: u0,
        referral-count: u0,
        badges-earned: u0
      } (map-get? member-reputation member)))
    )
    (asserts! (is-authorized contract-caller) ERR-NOT-AUTHORIZED)
    
    ;; Update last activity
    (map-set member-reputation member
      (merge current-rep { last-activity: block-height })
    )
    
    (ok true)
  )
)

(define-public (record-referral (referrer principal))
  (let
    (
      (current-rep (unwrap! (map-get? member-reputation referrer) ERR-MEMBER-NOT-FOUND))
      (new-referral-count (+ (get referral-count current-rep) u1))
    )
    (asserts! (is-authorized contract-caller) ERR-NOT-AUTHORIZED)
    
    (map-set member-reputation referrer
      (merge current-rep {
        referral-count: new-referral-count,
        score: (get-min MAX-SCORE (+ (get score current-rep) REFERRAL-BONUS)),
        last-activity: block-height
      })
    )
    
    ;; Check for top referrer badge
    (if (is-eq new-referral-count u10)
      (award-badge-internal referrer BADGE-TOP-REFERRER u0)
      true
    )
    
    (ok true)
  )
)


;; ============================================
;; Decay System (NEW in v6)
;; ============================================

(define-public (apply-decay (member principal))
  (let
    (
      (current-rep (unwrap! (map-get? member-reputation member) ERR-MEMBER-NOT-FOUND))
      (last-activity (get last-activity current-rep))
      (periods-inactive (/ (- block-height last-activity) DECAY-PERIOD-BLOCKS))
      (current-score (get score current-rep))
    )
    (if (and (> periods-inactive u0) (> current-score BASE-SCORE))
      (let
        (
          (decay-amount (/ (* current-score (* periods-inactive DECAY-PERCENT)) u100))
          (new-score (if (> decay-amount current-score) 
                       BASE-SCORE 
                       (get-max BASE-SCORE (- current-score decay-amount))))
        )
        (map-set member-reputation member
          (merge current-rep { score: new-score }))
        (ok new-score)
      )
      (ok current-score)
    )
  )
)


;; ============================================
;; Badge System (NEW in v6)
;; ============================================

(define-private (check-and-award-badges (member principal) (circles uint) (defaults uint) (streak uint))
  (begin
    ;; First circle badge
    (if (is-eq circles u1)
      (award-badge-internal member BADGE-FIRST-CIRCLE u0)
      true
    )
    ;; 5 circles badge
    (if (is-eq circles u5)
      (award-badge-internal member BADGE-5-CIRCLES u0)
      true
    )
    ;; 10 circles badge
    (if (is-eq circles u10)
      (award-badge-internal member BADGE-10-CIRCLES u0)
      true
    )
    ;; Perfect record badge (10+ circles, 0 defaults)
    (if (and (>= circles u10) (is-eq defaults u0))
      (award-badge-internal member BADGE-PERFECT-RECORD u0)
      true
    )
    ;; Veteran badge (25+ circles)
    (if (is-eq circles u25)
      (award-badge-internal member BADGE-VETERAN u0)
      true
    )
    true
  )
)

(define-private (award-badge-internal (member principal) (badge-type uint) (circle-id uint))
  (let
    (
      (existing (map-get? member-badges { member: member, badge-type: badge-type }))
    )
    (if (is-none existing)
      (begin
        (map-set member-badges { member: member, badge-type: badge-type }
          { earned-at: block-height, circle-id: circle-id })
        ;; Update badge count
        (match (map-get? member-reputation member)
          rep (map-set member-reputation member
                (merge rep { badges-earned: (+ (get badges-earned rep) u1) }))
          false
        )
        true
      )
      true
    )
  )
)

(define-public (award-badge (member principal) (badge-type uint) (circle-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (award-badge-internal member badge-type circle-id))
  )
)


;; ============================================
;; Score Calculation
;; ============================================

(define-private (calculate-new-score (current-score uint) (change uint) (is-positive bool))
  (if is-positive
    (get-min MAX-SCORE (+ current-score change))
    (if (> change current-score)
      MIN-SCORE
      (- current-score change))
  )
)


;; ============================================
;; Read-Only Functions
;; ============================================

(define-read-only (get-member-score (member principal))
  (match (map-get? member-reputation member)
    rep (ok (get score rep))
    (ok BASE-SCORE)
  )
)

(define-read-only (get-member-reputation (member principal))
  (map-get? member-reputation member)
)

(define-read-only (meets-requirement (member principal) (min-score uint))
  (let
    (
      (rep (map-get? member-reputation member))
    )
    (match rep
      r (>= (get score r) min-score)
      false
    )
  )
)

(define-read-only (get-member-tier (member principal))
  (let
    (
      (score (default-to BASE-SCORE 
               (match (map-get? member-reputation member)
                 rep (some (get score rep))
                 none)))
    )
    (if (>= score u2000)
      { tier: u5, name: "Diamond" }
      (if (>= score u1000)
        { tier: u4, name: "Platinum" }
        (if (>= score u600)
          { tier: u3, name: "Gold" }
          (if (>= score u300)
            { tier: u2, name: "Silver" }
            { tier: u1, name: "Bronze" }
          )
        )
      )
    )
  )
)

(define-read-only (get-badge-count (member principal))
  (match (map-get? member-reputation member)
    rep (ok (get badges-earned rep))
    (ok u0)
  )
)

(define-read-only (has-badge (member principal) (badge-type uint))
  (is-some (map-get? member-badges { member: member, badge-type: badge-type }))
)

(define-read-only (get-badge-info (member principal) (badge-type uint))
  (map-get? member-badges { member: member, badge-type: badge-type })
)

(define-read-only (get-circle-record (circle-id uint) (member principal))
  (map-get? circle-member-record { circle-id: circle-id, member: member })
)

(define-read-only (get-fee-discount (member principal))
  (let
    (
      (tier-info (get-member-tier member))
      (tier (get tier tier-info))
    )
    (if (is-eq tier u5) u500      ;; 50% = 500 bps
      (if (is-eq tier u4) u300    ;; 30%
        (if (is-eq tier u3) u200  ;; 20%
          (if (is-eq tier u2) u100 ;; 10%
            u0))))                 ;; 0%
  )
)
