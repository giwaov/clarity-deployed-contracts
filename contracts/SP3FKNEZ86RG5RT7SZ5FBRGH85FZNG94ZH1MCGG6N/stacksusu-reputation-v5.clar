;; StackSusu Reputation v5
;; Member trust and reputation tracking system

(define-constant CONTRACT-OWNER tx-sender)

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u2000))
(define-constant ERR-MEMBER-NOT-FOUND (err u2001))
(define-constant ERR-INVALID-SCORE (err u2002))
(define-constant ERR-ALREADY-RECORDED (err u2003))

;; Reputation score weights
(define-constant COMPLETION-WEIGHT u100)
(define-constant DEFAULT-PENALTY u200)
(define-constant ON-TIME-BONUS u20)
(define-constant VOLUME-WEIGHT u1)

;; Starting reputation score
(define-constant BASE-SCORE u500)
(define-constant MAX-SCORE u1000)
(define-constant MIN-SCORE u0)

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
    joined-at: uint
  }
)

;; Circle-specific member records (to prevent double recording)
(define-map circle-member-record
  { circle-id: uint, member: principal }
  { completed: bool, defaulted: bool, recorded-at: uint }
)

;; Authorized contracts that can update reputation
(define-map authorized-updaters principal bool)

;; Read-only: Check if caller is authorized
(define-read-only (is-authorized (caller principal))
  (or 
    (is-eq caller CONTRACT-OWNER)
    (default-to false (map-get? authorized-updaters caller))
  )
)

;; Admin: Authorize a contract to update reputation
(define-public (authorize-updater (updater principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-updaters updater true))
  )
)

;; Admin: Revoke updater authorization
(define-public (revoke-updater (updater principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-delete authorized-updaters updater))
  )
)

;; Initialize member reputation (called on first circle join)
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
          joined-at: block-height
        })
        (ok true)
      )
      (ok true) ;; Already initialized
    )
  )
)

;; Record successful circle completion
(define-public (record-completion (member principal) (circle-id uint) (payout-amount uint) (was-on-time bool))
  (let
    (
      (existing-record (map-get? circle-member-record { circle-id: circle-id, member: member }))
      (current-rep (unwrap! (map-get? member-reputation member) ERR-MEMBER-NOT-FOUND))
      (completion-bonus COMPLETION-WEIGHT)
      (time-bonus (if was-on-time ON-TIME-BONUS u0))
      (new-score (calculate-new-score (get score current-rep) (+ completion-bonus time-bonus) true))
    )
    (asserts! (is-authorized contract-caller) ERR-NOT-AUTHORIZED)
    (asserts! (or (is-none existing-record) 
                  (not (get completed (unwrap-panic existing-record)))) 
              ERR-ALREADY-RECORDED)
    
    ;; Update circle record
    (map-set circle-member-record 
      { circle-id: circle-id, member: member }
      { completed: true, defaulted: false, recorded-at: block-height }
    )
    
    ;; Update reputation
    (map-set member-reputation member
      (merge current-rep {
        circles-completed: (+ (get circles-completed current-rep) u1),
        on-time-payments: (if was-on-time 
                            (+ (get on-time-payments current-rep) u1)
                            (get on-time-payments current-rep)),
        late-payments: (if was-on-time
                         (get late-payments current-rep)
                         (+ (get late-payments current-rep) u1)),
        total-payouts-received: (+ (get total-payouts-received current-rep) payout-amount),
        score: new-score,
        last-activity: block-height
      })
    )
    (ok true)
  )
)

;; Record circle default (member failed to complete)
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
    
    ;; Update circle record
    (map-set circle-member-record
      { circle-id: circle-id, member: member }
      { completed: false, defaulted: true, recorded-at: block-height }
    )
    
    ;; Update reputation with penalty
    (map-set member-reputation member
      (merge current-rep {
        circles-defaulted: (+ (get circles-defaulted current-rep) u1),
        score: new-score,
        last-activity: block-height
      })
    )
    (ok true)
  )
)

;; Record deposit contribution (volume tracking)
(define-public (record-contribution (member principal) (amount uint))
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
        last-activity: block-height,
        joined-at: block-height
      } (map-get? member-reputation member)))
    )
    (asserts! (is-authorized contract-caller) ERR-NOT-AUTHORIZED)
    
    (map-set member-reputation member
      (merge current-rep {
        total-volume: (+ (get total-volume current-rep) amount),
        last-activity: block-height
      })
    )
    (ok true)
  )
)

;; Calculate new score with bounds checking
(define-private (calculate-new-score (current-score uint) (change uint) (is-positive bool))
  (if is-positive
    (if (> (+ current-score change) MAX-SCORE)
      MAX-SCORE
      (+ current-score change)
    )
    (if (< current-score change)
      MIN-SCORE
      (- current-score change)
    )
  )
)

;; Read-only: Get member's reputation score
(define-read-only (get-member-score (member principal))
  (ok (default-to BASE-SCORE 
    (get score (map-get? member-reputation member))))
)

;; Read-only: Get full member reputation data
(define-read-only (get-member-reputation (member principal))
  (ok (map-get? member-reputation member))
)

;; Read-only: Check if member meets minimum reputation requirement
(define-read-only (meets-requirement (member principal) (min-score uint))
  (let
    (
      (member-score (default-to BASE-SCORE 
        (get score (map-get? member-reputation member))))
    )
    (>= member-score min-score)
  )
)

;; Read-only: Get member's completion rate (percentage * 100)
(define-read-only (get-completion-rate (member principal))
  (let
    (
      (rep (map-get? member-reputation member))
    )
    (match rep
      r (let
          (
            (total (+ (get circles-completed r) (get circles-defaulted r)))
          )
          (if (is-eq total u0)
            (ok u10000) ;; 100% for new members
            (ok (/ (* (get circles-completed r) u10000) total))
          )
        )
      (ok u10000) ;; 100% for unknown members
    )
  )
)

;; Read-only: Get reputation tier (0-4)
(define-read-only (get-reputation-tier (member principal))
  (let
    (
      (score (default-to BASE-SCORE (get score (map-get? member-reputation member))))
    )
    (if (>= score u900) u4        ;; Diamond
      (if (>= score u750) u3      ;; Gold
        (if (>= score u500) u2    ;; Silver
          (if (>= score u250) u1  ;; Bronze
            u0                     ;; Unranked
          )
        )
      )
    )
  )
)

;; Read-only: Check circle member record
(define-read-only (get-circle-record (circle-id uint) (member principal))
  (ok (map-get? circle-member-record { circle-id: circle-id, member: member }))
)
