;; ============================================
;; CONSTANTS
;; ============================================

(define-constant CONTRACT_OWNER tx-sender)

;; Error codes
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ALREADY_CHECKED_IN (err u200))
(define-constant ERR_NOT_ELIGIBLE (err u201))
(define-constant ERR_BADGE_ALREADY_CLAIMED (err u202))
(define-constant ERR_INVALID_BADGE_TYPE (err u203))
(define-constant ERR_USER_NOT_FOUND (err u204))

;; Badge type constants (must match presence-badges contract)
(define-constant BADGE_WEEK_WARRIOR u1)
(define-constant BADGE_MONTHLY_MASTER u2)
(define-constant BADGE_CENTURY_CLUB u3)
(define-constant BADGE_CHATTERBOX u4)
(define-constant BADGE_LOVE_MACHINE u5)
(define-constant BADGE_OG_PRESENCE u6)

;; Badge requirements
(define-constant STREAK_WEEK u7)
(define-constant STREAK_MONTH u30)
(define-constant STREAK_CENTURY u100)
(define-constant COMMENTS_THRESHOLD u100)
(define-constant LIKES_THRESHOLD u500)
(define-constant CHECKINS_THRESHOLD u100)

;; Approximate blocks per day (Stacks ~10 min blocks = ~144 blocks/day)
(define-constant BLOCKS_PER_DAY u144)

;; ============================================
;; DATA STORAGE
;; ============================================

;; User stats map
(define-map user-stats principal
  {
    last-check-in: uint,      ;; Block height of last check-in
    current-streak: uint,     ;; Current consecutive days
    longest-streak: uint,     ;; Best streak achieved
    total-check-ins: uint,    ;; Total check-ins ever
    total-likes: uint,        ;; Total likes logged
    total-comments: uint      ;; Total comments logged
  }
)

;; Track claimed badges per user
(define-map user-badges
  { user: principal, badge-type: uint }
  bool
)

;; Global stats
(define-data-var total-users uint u0)
(define-data-var total-check-ins uint u0)

;; ============================================
;; CORE FUNCTIONS
;; ============================================

;; Daily check-in function
(define-public (check-in)
  (let
    (
      (caller tx-sender)
      (current-block stacks-block-height)
      (existing-stats (map-get? user-stats caller))
    )
    (match existing-stats
      ;; User exists - update streak
      stats
        (let
          (
            (last-check-in (get last-check-in stats))
            (blocks-since-last (- current-block last-check-in))
            (current-streak (get current-streak stats))
          )
          ;; Check if already checked in today (within same day window)
          (asserts! (>= blocks-since-last BLOCKS_PER_DAY) ERR_ALREADY_CHECKED_IN)

          ;; Calculate new streak
          (let
            (
              (new-streak
                (if (<= blocks-since-last (* BLOCKS_PER_DAY u2))
                  ;; Checked in within ~48 hours - continue streak
                  (+ current-streak u1)
                  ;; Streak broken - reset
                  u1
                )
              )
              (new-longest (if (> new-streak (get longest-streak stats))
                new-streak
                (get longest-streak stats)
              ))
            )
            ;; Update user stats
            (map-set user-stats caller {
              last-check-in: current-block,
              current-streak: new-streak,
              longest-streak: new-longest,
              total-check-ins: (+ (get total-check-ins stats) u1),
              total-likes: (get total-likes stats),
              total-comments: (get total-comments stats)
            })
            ;; Update global stats
            (var-set total-check-ins (+ (var-get total-check-ins) u1))
            ;; Emit event
            (print {
              event: "check-in",
              user: caller,
              streak: new-streak,
              total-check-ins: (+ (get total-check-ins stats) u1),
              block-height: current-block
            })
            (ok {
              streak: new-streak,
              total-check-ins: (+ (get total-check-ins stats) u1)
            })
          )
        )
      ;; New user - initialize
      (begin
        (map-set user-stats caller {
          last-check-in: current-block,
          current-streak: u1,
          longest-streak: u1,
          total-check-ins: u1,
          total-likes: u0,
          total-comments: u0
        })
        ;; Update global stats
        (var-set total-users (+ (var-get total-users) u1))
        (var-set total-check-ins (+ (var-get total-check-ins) u1))
        ;; Emit event
        (print {
          event: "new-user-check-in",
          user: caller,
          streak: u1,
          block-height: current-block
        })
        (ok { streak: u1, total-check-ins: u1 })
      )
    )
  )
)

;; Log likes activity
(define-public (log-likes (count uint))
  (let
    (
      (caller tx-sender)
      (existing-stats (map-get? user-stats caller))
    )
    (match existing-stats
      stats
        (begin
          (map-set user-stats caller (merge stats {
            total-likes: (+ (get total-likes stats) count)
          }))
          (print {
            event: "likes-logged",
            user: caller,
            count: count,
            new-total: (+ (get total-likes stats) count)
          })
          (ok (+ (get total-likes stats) count))
        )
      ERR_USER_NOT_FOUND
    )
  )
)

;; Log comments activity
(define-public (log-comments (count uint))
  (let
    (
      (caller tx-sender)
      (existing-stats (map-get? user-stats caller))
    )
    (match existing-stats
      stats
        (begin
          (map-set user-stats caller (merge stats {
            total-comments: (+ (get total-comments stats) count)
          }))
          (print {
            event: "comments-logged",
            user: caller,
            count: count,
            new-total: (+ (get total-comments stats) count)
          })
          (ok (+ (get total-comments stats) count))
        )
      ERR_USER_NOT_FOUND
    )
  )
)

;; ============================================
;; BADGE CLAIMING
;; ============================================

;; Claim a badge if eligible
(define-public (claim-badge (badge-type uint))
  (let
    (
      (caller tx-sender)
      (stats (unwrap! (map-get? user-stats caller) ERR_USER_NOT_FOUND))
    )
    ;; Check if badge already claimed
    (asserts!
      (is-none (map-get? user-badges { user: caller, badge-type: badge-type }))
      ERR_BADGE_ALREADY_CLAIMED
    )
    ;; Check eligibility based on badge type
    (asserts! (check-badge-eligibility badge-type stats) ERR_NOT_ELIGIBLE)
    ;; Mark badge as claimed
    (map-set user-badges { user: caller, badge-type: badge-type } true)
    ;; Mint the NFT badge via the badge contract
    (try! (contract-call? .presence-badges mint caller badge-type))
    ;; Emit event
    (print {
      event: "badge-claimed",
      user: caller,
      badge-type: badge-type,
      block-height: stacks-block-height
    })
    (ok badge-type)
  )
)

;; Check if user is eligible for a specific badge
(define-private (check-badge-eligibility (badge-type uint) (stats {
  last-check-in: uint,
  current-streak: uint,
  longest-streak: uint,
  total-check-ins: uint,
  total-likes: uint,
  total-comments: uint
}))
  (if (is-eq badge-type BADGE_WEEK_WARRIOR)
    (>= (get longest-streak stats) STREAK_WEEK)
    (if (is-eq badge-type BADGE_MONTHLY_MASTER)
      (>= (get longest-streak stats) STREAK_MONTH)
      (if (is-eq badge-type BADGE_CENTURY_CLUB)
        (>= (get longest-streak stats) STREAK_CENTURY)
        (if (is-eq badge-type BADGE_CHATTERBOX)
          (>= (get total-comments stats) COMMENTS_THRESHOLD)
          (if (is-eq badge-type BADGE_LOVE_MACHINE)
            (>= (get total-likes stats) LIKES_THRESHOLD)
            (if (is-eq badge-type BADGE_OG_PRESENCE)
              (>= (get total-check-ins stats) CHECKINS_THRESHOLD)
              false
            )
          )
        )
      )
    )
  )
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

;; Get user stats
(define-read-only (get-user-stats (user principal))
  (map-get? user-stats user)
)

;; Get user's current streak
(define-read-only (get-streak (user principal))
  (match (map-get? user-stats user)
    stats (ok (get current-streak stats))
    (ok u0)
  )
)

;; Get user's longest streak
(define-read-only (get-longest-streak (user principal))
  (match (map-get? user-stats user)
    stats (ok (get longest-streak stats))
    (ok u0)
  )
)

;; Check if user has claimed a specific badge
(define-read-only (has-badge (user principal) (badge-type uint))
  (is-some (map-get? user-badges { user: user, badge-type: badge-type }))
)

;; Check if user is eligible for a badge
(define-read-only (is-eligible-for-badge (user principal) (badge-type uint))
  (match (map-get? user-stats user)
    stats (ok (check-badge-eligibility badge-type stats))
    (ok false)
  )
)

;; Get all badge statuses for a user
(define-read-only (get-badge-status (user principal))
  (ok {
    week-warrior: (has-badge user BADGE_WEEK_WARRIOR),
    monthly-master: (has-badge user BADGE_MONTHLY_MASTER),
    century-club: (has-badge user BADGE_CENTURY_CLUB),
    chatterbox: (has-badge user BADGE_CHATTERBOX),
    love-machine: (has-badge user BADGE_LOVE_MACHINE),
    og-presence: (has-badge user BADGE_OG_PRESENCE)
  })
)

;; Get global stats
(define-read-only (get-global-stats)
  (ok {
    total-users: (var-get total-users),
    total-check-ins: (var-get total-check-ins)
  })
)

;; Check if user can check in (not already checked in today)
(define-read-only (can-check-in (user principal))
  (match (map-get? user-stats user)
    stats
      (let
        (
          (blocks-since-last (- stacks-block-height (get last-check-in stats)))
        )
        (ok (>= blocks-since-last BLOCKS_PER_DAY))
      )
    (ok true)  ;; New user can always check in
  )
)

;; Get badge requirements (for frontend display)
(define-read-only (get-badge-requirements)
  (ok {
    week-warrior: { type: "streak", requirement: STREAK_WEEK },
    monthly-master: { type: "streak", requirement: STREAK_MONTH },
    century-club: { type: "streak", requirement: STREAK_CENTURY },
    chatterbox: { type: "comments", requirement: COMMENTS_THRESHOLD },
    love-machine: { type: "likes", requirement: LIKES_THRESHOLD },
    og-presence: { type: "check-ins", requirement: CHECKINS_THRESHOLD }
  })
)
