;; BitTrust Reputation System
;; On-chain credit scoring for decentralized lending

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-found (err u201))
(define-constant err-invalid-score (err u202))

;; Maximum reputation score
(define-constant max-reputation u1000)

;; Data Maps
(define-map reputation-scores
  { user: principal }
  {
    score: uint, ;; 0-1000
    total-loans: uint,
    successful-repayments: uint,
    defaults: uint,
    total-volume: uint,
    last-updated: uint
  }
)

(define-map reputation-history
  { user: principal, timestamp: uint }
  {
    score: uint,
    event-type: (string-ascii 20), ;; "repayment", "default", "new-loan"
    loan-id: uint
  }
)

;; Read-only functions
(define-read-only (get-reputation (user principal))
  (default-to
    { score: u500, total-loans: u0, successful-repayments: u0, 
      defaults: u0, total-volume: u0, last-updated: u0 }
    (map-get? reputation-scores { user: user })
  )
)

(define-read-only (get-reputation-score (user principal))
  (get score (get-reputation user))
)

(define-read-only (calculate-borrowing-limit (user principal))
  (let
    (
      (reputation (get-reputation user))
      (score (get score reputation))
      (total-volume (get total-volume reputation))
    )
    ;; Base limit increases with reputation score
    ;; Score 500 = 1000 STX, Score 1000 = 10000 STX
    (ok (+ u1000000000 (* score u10000000)))
  )
)

(define-read-only (get-recommended-interest-rate (user principal))
  (let
    (
      (score (get-reputation-score user))
    )
    ;; Higher score = lower interest rate
    ;; Score 1000 = 5%, Score 500 = 15%, Score 0 = 25%
    (ok (- u2500 (/ (* score u20) u100)))
  )
)

(define-read-only (can-borrow-uncollateralized (user principal))
  (let
    (
      (reputation (get-reputation user))
      (score (get score reputation))
      (defaults (get defaults reputation))
    )
    ;; Require score > 750 and no defaults for uncollateralized loans
    (ok (and (> score u750) (is-eq defaults u0)))
  )
)

;; Public functions

;; Initialize reputation for new user
(define-public (initialize-reputation)
  (let
    (
      (existing (map-get? reputation-scores { user: tx-sender }))
    )
    (asserts! (is-none existing) (err u203))
    (map-set reputation-scores
      { user: tx-sender }
      {
        score: u500, ;; Start with neutral score
        total-loans: u0,
        successful-repayments: u0,
        defaults: u0,
        total-volume: u0,
        last-updated: stacks-block-height
      }
    )
    (ok true)
  )
)

;; Record new loan (called by lending contract)
(define-public (record-loan (user principal) (amount uint) (loan-id uint))
  (let
    (
      (reputation (get-reputation user))
      (new-total-loans (+ (get total-loans reputation) u1))
      (new-total-volume (+ (get total-volume reputation) amount))
    )
    (map-set reputation-scores
      { user: user }
      (merge reputation {
        total-loans: new-total-loans,
        total-volume: new-total-volume,
        last-updated: stacks-block-height
      })
    )
    
    ;; Record history
    (map-set reputation-history
      { user: user, timestamp: stacks-block-height }
      {
        score: (get score reputation),
        event-type: "new-loan",
        loan-id: loan-id
      }
    )
    
    (ok true)
  )
)

;; Record successful repayment
(define-public (record-repayment (user principal) (amount uint) (loan-id uint) (on-time bool))
  (let
    (
      (reputation (get-reputation user))
      (current-score (get score reputation))
      (new-repayments (+ (get successful-repayments reputation) u1))
      (repayment-rate (/ (* new-repayments u100) (get total-loans reputation)))
      ;; Calculate score increase: on-time = +20 points, late = +10 points
      (score-increase (if on-time u20 u10))
      (new-score (min max-reputation (+ current-score score-increase)))
    )
    (map-set reputation-scores
      { user: user }
      (merge reputation {
        score: new-score,
        successful-repayments: new-repayments,
        last-updated: stacks-block-height
      })
    )
    
    ;; Record history
    (map-set reputation-history
      { user: user, timestamp: stacks-block-height }
      {
        score: new-score,
        event-type: "repayment",
        loan-id: loan-id
      }
    )
    
    (ok new-score)
  )
)

;; Record default
(define-public (record-default (user principal) (loan-id uint))
  (let
    (
      (reputation (get-reputation user))
      (current-score (get score reputation))
      (new-defaults (+ (get defaults reputation) u1))
      ;; Severe penalty for defaults: -100 points
      (score-decrease u100)
      (new-score (if (> current-score score-decrease)
                    (- current-score score-decrease)
                    u0))
    )
    (map-set reputation-scores
      { user: user }
      (merge reputation {
        score: new-score,
        defaults: new-defaults,
        last-updated: stacks-block-height
      })
    )
    
    ;; Record history
    (map-set reputation-history
      { user: user, timestamp: stacks-block-height }
      {
        score: new-score,
        event-type: "default",
        loan-id: loan-id
      }
    )
    
    (ok new-score)
  )
)

;; Calculate comprehensive reputation score
(define-public (recalculate-reputation (user principal))
  (let
    (
      (reputation (get-reputation user))
      (total-loans (get total-loans reputation))
      (successful-repayments (get successful-repayments reputation))
      (defaults (get defaults reputation))
      (total-volume (get total-volume reputation))
    )
    (if (is-eq total-loans u0)
      (ok u500) ;; Default score for new users
      (let
        (
          ;; Repayment rate component (0-400 points)
          (repayment-rate (/ (* successful-repayments u100) total-loans))
          (repayment-score (/ (* repayment-rate u4) u1))
          
          ;; Volume component (0-300 points)
          ;; More volume = higher score (capped)
          (volume-score (min u300 (/ total-volume u1000000)))
          
          ;; Loan count component (0-200 points)
          (loan-count-score (min u200 (* total-loans u10)))
          
          ;; Default penalty (-100 points per default)
          (default-penalty (* defaults u100))
          
          ;; Base score (100 points)
          (base-score u100)
          
          ;; Calculate final score
          (calculated-score (if (> (+ base-score repayment-score volume-score loan-count-score) default-penalty)
                              (- (+ base-score repayment-score volume-score loan-count-score) default-penalty)
                              u0))
          (final-score (min max-reputation calculated-score))
        )
        (map-set reputation-scores
          { user: user }
          (merge reputation {
            score: final-score,
            last-updated: stacks-block-height
          })
        )
        (ok final-score)
      )
    )
  )
)

;; Private helper functions
(define-private (min (a uint) (b uint))
  (if (< a b) a b)
)

(define-private (max (a uint) (b uint))
  (if (> a b) a b)
)
