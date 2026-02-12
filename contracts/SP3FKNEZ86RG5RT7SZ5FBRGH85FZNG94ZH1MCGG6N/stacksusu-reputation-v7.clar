;; StackSusu Reputation v7
;; Simplified reputation system - no authorization required

(define-constant CONTRACT-OWNER tx-sender)

;; Error constants
(define-constant ERR-NOT-FOUND (err u2001))
(define-constant ERR-INVALID-SCORE (err u2002))
(define-constant ERR-INIT-FAILED (err u2003))

;; Score configuration
(define-constant BASE-SCORE u500)
(define-constant MAX-SCORE u1000)
(define-constant MIN-SCORE u0)

;; Helper function for min
(define-private (get-min (a uint) (b uint))
  (if (<= a b) a b)
)

;; Member reputation data
(define-map member-reputation
  principal
  {
    score: uint,
    contributions-made: uint,
    contributions-missed: uint,
    payouts-received: uint,
    circles-joined: uint,
    circles-completed: uint,
    last-activity: uint,
    initialized: bool
  }
)


;; ============================================
;; Core Functions
;; ============================================

(define-public (initialize-member (member principal))
  (begin
    (asserts! true ERR-INIT-FAILED) ;; Sets error type for function
    (if (is-none (map-get? member-reputation member))
      (map-set member-reputation member {
        score: BASE-SCORE,
        contributions-made: u0,
        contributions-missed: u0,
        payouts-received: u0,
        circles-joined: u0,
        circles-completed: u0,
        last-activity: block-height,
        initialized: true
      })
      true ;; Already exists, do nothing
    )
    (ok true)
  )
)

(define-public (record-contribution (member principal))
  (let
    (
      (rep (default-to {
        score: BASE-SCORE, contributions-made: u0, contributions-missed: u0,
        payouts-received: u0, circles-joined: u0, circles-completed: u0,
        last-activity: block-height, initialized: true
      } (map-get? member-reputation member)))
      (new-score (get-min MAX-SCORE (+ (get score rep) u10)))
    )
    (asserts! true ERR-INIT-FAILED)
    (map-set member-reputation member (merge rep {
      score: new-score,
      contributions-made: (+ (get contributions-made rep) u1),
      last-activity: block-height
    }))
    (ok new-score)
  )
)

(define-public (record-missed-contribution (member principal))
  (let
    (
      (rep (default-to {
        score: BASE-SCORE, contributions-made: u0, contributions-missed: u0,
        payouts-received: u0, circles-joined: u0, circles-completed: u0,
        last-activity: block-height, initialized: true
      } (map-get? member-reputation member)))
      (penalty (get-min (get score rep) u25))
      (new-score (- (get score rep) penalty))
    )
    (asserts! true ERR-INIT-FAILED)
    (map-set member-reputation member (merge rep {
      score: new-score,
      contributions-missed: (+ (get contributions-missed rep) u1),
      last-activity: block-height
    }))
    (ok new-score)
  )
)

(define-public (record-payout (member principal))
  (let
    (
      (rep (default-to {
        score: BASE-SCORE, contributions-made: u0, contributions-missed: u0,
        payouts-received: u0, circles-joined: u0, circles-completed: u0,
        last-activity: block-height, initialized: true
      } (map-get? member-reputation member)))
    )
    (asserts! true ERR-INIT-FAILED)
    (map-set member-reputation member (merge rep {
      payouts-received: (+ (get payouts-received rep) u1),
      last-activity: block-height
    }))
    (ok true)
  )
)

(define-public (record-circle-join (member principal))
  (let
    (
      (rep (default-to {
        score: BASE-SCORE, contributions-made: u0, contributions-missed: u0,
        payouts-received: u0, circles-joined: u0, circles-completed: u0,
        last-activity: block-height, initialized: true
      } (map-get? member-reputation member)))
    )
    (asserts! true ERR-INIT-FAILED)
    (map-set member-reputation member (merge rep {
      circles-joined: (+ (get circles-joined rep) u1),
      last-activity: block-height
    }))
    (ok true)
  )
)

(define-public (record-circle-complete (member principal))
  (let
    (
      (rep (default-to {
        score: BASE-SCORE, contributions-made: u0, contributions-missed: u0,
        payouts-received: u0, circles-joined: u0, circles-completed: u0,
        last-activity: block-height, initialized: true
      } (map-get? member-reputation member)))
      (bonus (get-min u50 (- MAX-SCORE (get score rep))))
    )
    (asserts! true ERR-INIT-FAILED)
    (map-set member-reputation member (merge rep {
      score: (+ (get score rep) bonus),
      circles-completed: (+ (get circles-completed rep) u1),
      last-activity: block-height
    }))
    (ok true)
  )
)


;; ============================================
;; Read Functions
;; ============================================

(define-read-only (get-reputation (member principal))
  (ok (default-to {
    score: BASE-SCORE, contributions-made: u0, contributions-missed: u0,
    payouts-received: u0, circles-joined: u0, circles-completed: u0,
    last-activity: u0, initialized: false
  } (map-get? member-reputation member)))
)

(define-read-only (get-score (member principal))
  (ok (get score (default-to {
    score: BASE-SCORE, contributions-made: u0, contributions-missed: u0,
    payouts-received: u0, circles-joined: u0, circles-completed: u0,
    last-activity: u0, initialized: false
  } (map-get? member-reputation member))))
)

(define-read-only (is-initialized (member principal))
  (is-some (map-get? member-reputation member))
)

(define-read-only (get-tier (member principal))
  (let
    (
      (score (get score (default-to {
        score: BASE-SCORE, contributions-made: u0, contributions-missed: u0,
        payouts-received: u0, circles-joined: u0, circles-completed: u0,
        last-activity: u0, initialized: false
      } (map-get? member-reputation member))))
    )
    (if (>= score u900) u5      ;; Legendary
      (if (>= score u750) u4    ;; Expert
        (if (>= score u600) u3  ;; Advanced
          (if (>= score u400) u2 ;; Intermediate
            u1))))              ;; Beginner
  )
)
