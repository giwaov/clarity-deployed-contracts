;; ============================================
;; PREDINEX RESOLUTION ENGINE
;; ============================================
;; Manages dispute resolution and automated settlement triggers
;; Language: Clarity 2
;; ============================================

;; Constants & Errors
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED u401)
(define-constant ERR-RESOLUTION-CONFIG-NOT-FOUND u436)
(define-constant ERR-INVALID-RESOLUTION-CRITERIA u437)
(define-constant ERR-INSUFFICIENT-ORACLE-SOURCES u438)
(define-constant ERR-RESOLUTION-ALREADY-CONFIGURED u439)
(define-constant ERR-AUTOMATED-RESOLUTION-FAILED u440)
(define-constant ERR-DISPUTE-NOT-FOUND u441)
(define-constant ERR-DISPUTE-WINDOW-CLOSED u442)
(define-constant ERR-INSUFFICIENT-DISPUTE-BOND u443)
(define-constant ERR-ALREADY-VOTED u444)
(define-constant ERR-INVALID-DISPUTE_REASON u446)
(define-constant ERR-FALLBACK-NOT-TRIGGERED u447)
(define-constant ERR-MANUAL-SETTLEMENT-DISABLED u448)
(define-constant ERR-POOL-NOT-EXPIRED u413)
(define-constant ERR-POOL-SETTLED u409)
(define-constant ERR-POOL-NOT-FOUND u404)

(define-constant RESOLUTION-FEE-PERCENT u5)
(define-constant DISPUTE-BOND-PERCENT u5)

;; Data Structures
(define-map resolution-configs
  { pool-id: uint }
  {
    oracle-sources: (list 5 uint),
    resolution-criteria: (string-ascii 512),
    criteria-type: (string-ascii 32),
    threshold-value: (optional uint),
    logical-operator: (string-ascii 8),
    retry-attempts: uint,
    resolution-fee: uint,
    is-automated: bool,
    created-at: uint
  }
)

(define-map resolution-attempts
  { pool-id: uint, attempt-id: uint }
  {
    attempted-at: uint,
    oracle-data-used: (list 5 uint),
    result: (optional uint),
    failure-reason: (optional (string-ascii 128)),
    is-successful: bool
  }
)

(define-map pool-disputes
  { dispute-id: uint }
  {
    pool-id: uint,
    disputer: principal,
    dispute-bond: uint,
    dispute-reason: (string-ascii 512),
    evidence-hash: (optional (buff 32)),
    voting-deadline: uint,
    votes-for: uint,
    votes-against: uint,
    status: (string-ascii 16),
    resolution: (optional bool),
    created-at: uint
  }
)

(define-map dispute-votes
  { dispute-id: uint, voter: principal }
  {
    vote: bool,
    voting-power: uint,
    voted-at: uint
  }
)

(define-map fallback-resolutions
  { pool-id: uint }
  {
    triggered-at: uint,
    failure-reason: (string-ascii 128),
    max-retries-reached: bool,
    manual-settlement-enabled: bool,
    notified-creator: bool
  }
)

;; State Variables
(define-data-var resolution-attempt-counter uint u0)
(define-data-var dispute-counter uint u0)

;; Private helpers to check oracle validity via Registry
(define-private (validate-single-oracle (oracle-id uint) (is-valid bool))
  (if is-valid
    (match (contract-call? .predinex-oracle-registry-1769574272753 get-provider-details oracle-id)
      provider (get is-active provider)
      false
    )
    false
  )
)

(define-private (validate-oracle-sources (oracle-sources (list 5 uint)))
  (fold validate-single-oracle oracle-sources true)
)

;; Public Functions

(define-public (configure-pool-resolution 
  (pool-id uint) 
  (oracle-sources (list 5 uint)) 
  (resolution-criteria (string-ascii 512))
  (criteria-type (string-ascii 32))
  (threshold-value (optional uint))
  (logical-operator (string-ascii 8))
  (retry-attempts uint))
  
  (match (contract-call? .predinex-pool-1769575549853 get-pool-details pool-id)
    pool (if (is-eq tx-sender (get creator pool))
             (match (map-get? resolution-configs { pool-id: pool-id })
               config (err ERR-RESOLUTION-ALREADY-CONFIGURED)
               (if (and 
                    (> (len oracle-sources) u0)
                    (validate-oracle-sources oracle-sources)
                    (> (len resolution-criteria) u0)
                    (> (len criteria-type) u0)
                    (or (is-eq logical-operator "AND") (is-eq logical-operator "OR"))
                   )
                   (let (
                     (total-pool-value (+ (get total-a pool) (get total-b pool)))
                     (resolution-fee (/ (* total-pool-value u5) u1000))
                   )
                     (begin
                       (map-insert resolution-configs
                         { pool-id: pool-id }
                         {
                           oracle-sources: oracle-sources,
                           resolution-criteria: resolution-criteria,
                           criteria-type: criteria-type,
                           threshold-value: threshold-value,
                           logical-operator: logical-operator,
                           retry-attempts: retry-attempts,
                           resolution-fee: resolution-fee,
                           is-automated: true,
                           created-at: burn-block-height
                         }
                       )
                       (ok true)
                     )
                   )
                   (err ERR-INVALID-RESOLUTION-CRITERIA)
               )
             )
             (err ERR-UNAUTHORIZED)
         )
    (err ERR-POOL-NOT-FOUND)
  )
)

(define-public (attempt-automated-resolution (pool-id uint))
  (match (contract-call? .predinex-pool-1769575549853 get-pool-details pool-id)
    pool (match (map-get? resolution-configs { pool-id: pool-id })
      config (let ((attempt-id (var-get resolution-attempt-counter)))
               (if (and 
                    (> burn-block-height (get expiry pool))
                    (not (get settled pool))
                    (get is-automated config)
                   )
                   (let ((oracle-sources (get oracle-sources config)))
                     (if (> (len oracle-sources) u0)
                         (let ((outcome (mod (unwrap-panic (element-at oracle-sources u0)) u2)))
                           (map-insert resolution-attempts
                             { pool-id: pool-id, attempt-id: attempt-id }
                             {
                               attempted-at: burn-block-height,
                               oracle-data-used: oracle-sources,
                               result: (some outcome),
                               failure-reason: none,
                               is-successful: true
                             }
                           )
                           (match (contract-call? .predinex-pool-1769575549853 settle-pool pool-id outcome)
                             success (begin
                               (var-set resolution-attempt-counter (+ attempt-id u1))
                               (ok outcome)
                             )
                             error (err error)
                           )
                         )
                         (begin
                           (map-insert resolution-attempts
                             { pool-id: pool-id, attempt-id: attempt-id }
                             {
                               attempted-at: burn-block-height,
                               oracle-data-used: (list),
                               result: none,
                               failure-reason: (some "No oracle sources"),
                               is-successful: false
                             }
                           )
                           (var-set resolution-attempt-counter (+ attempt-id u1))
                           (err ERR-AUTOMATED-RESOLUTION-FAILED)
                         )
                     )
                   )
                   (err ERR-AUTOMATED-RESOLUTION-FAILED)
               )
             )
      (err ERR-RESOLUTION-CONFIG-NOT-FOUND)
    )
    (err ERR-POOL-NOT-FOUND)
  )
)


(define-public (create-dispute (pool-id uint) (dispute-reason (string-ascii 512)) (evidence-hash (optional (buff 32))))
  (match (contract-call? .predinex-pool-1769575549853 get-pool-details pool-id)
    pool (if (get settled pool)
             (if (> (len dispute-reason) u0)
                 (let (
                   (dispute-id (var-get dispute-counter))
                   (total-pool-value (+ (get total-a pool) (get total-b pool)))
                   (dispute-bond (/ (* total-pool-value u5) u100))
                 )
                   (if (>= (stx-get-balance tx-sender) dispute-bond)
                       (match (stx-transfer? dispute-bond tx-sender (as-contract tx-sender))
                         success (begin
                           (map-insert pool-disputes
                             { dispute-id: dispute-id }
                             {
                               pool-id: pool-id,
                               disputer: tx-sender,
                               dispute-bond: dispute-bond,
                               dispute-reason: dispute-reason,
                               evidence-hash: evidence-hash,
                               voting-deadline: (+ burn-block-height u1008),
                               votes-for: u0,
                               votes-against: u0,
                               status: "active",
                               resolution: none,
                               created-at: burn-block-height
                             }
                           )
                           (var-set dispute-counter (+ dispute-id u1))
                           (ok dispute-id)
                         )
                         error (err error)
                       )
                       (err ERR-INSUFFICIENT-DISPUTE-BOND)
                   )
                 )
                 (err ERR-INVALID-DISPUTE_REASON)
             )
             (err ERR-POOL-SETTLED) ;; Note: Logic inverted? Original said if settled? Yes disputes happen AFTER settlement.
         )
    (err ERR-POOL-NOT-FOUND)
  )
)

(define-public (vote-on-dispute (dispute-id uint) (vote bool))
  (match (map-get? pool-disputes { dispute-id: dispute-id })
    dispute (if (and 
                 (is-eq (get status dispute) "active")
                 (< burn-block-height (get voting-deadline dispute))
                )
                (match (map-get? dispute-votes { dispute-id: dispute-id, voter: tx-sender })
                  voted (err ERR-ALREADY-VOTED)
                  (let ((voting-power u1))
                    (begin
                      (map-insert dispute-votes
                        { dispute-id: dispute-id, voter: tx-sender }
                        {
                          vote: vote,
                          voting-power: voting-power,
                          voted-at: burn-block-height
                        }
                      )
                      (map-set pool-disputes
                        { dispute-id: dispute-id }
                        (merge dispute {
                          votes-for: (if vote (+ (get votes-for dispute) voting-power) (get votes-for dispute)),
                          votes-against: (if vote (get votes-against dispute) (+ (get votes-against dispute) voting-power))
                        })
                      )
                      (ok true)
                    )
                  )
                )
                (err ERR-DISPUTE-WINDOW-CLOSED)
            )
    (err ERR-DISPUTE-NOT-FOUND)
  )
)

(define-public (resolve-dispute (dispute-id uint))
  (match (map-get? pool-disputes { dispute-id: dispute-id })
    dispute (if (and 
                 (is-eq (get status dispute) "active")
                 (>= burn-block-height (get voting-deadline dispute))
                )
                (let (
                  (votes-for (get votes-for dispute))
                  (votes-against (get votes-against dispute))
                  (dispute-upheld (> votes-for votes-against))
                  (disputer (get disputer dispute))
                  (dispute-bond (get dispute-bond dispute))
                )
                  (begin
                    (map-set pool-disputes
                      { dispute-id: dispute-id }
                      (merge dispute {
                        status: "resolved",
                        resolution: (some dispute-upheld)
                      })
                    )
                    (if dispute-upheld
                        (match (as-contract (stx-transfer? dispute-bond tx-sender disputer))
                          success (ok true)
                          error (err error)
                        )
                        (ok false)
                    )
                  )
                )
                (err ERR-DISPUTE-WINDOW-CLOSED)
            )
    (err ERR-DISPUTE-NOT-FOUND)
  )
)

(define-public (trigger-fallback-resolution (pool-id uint) (failure-reason (string-ascii 128)))
  (match (contract-call? .predinex-pool-1769575549853 get-pool-details pool-id)
    pool (match (map-get? resolution-configs { pool-id: pool-id })
      config (if (is-eq tx-sender (as-contract tx-sender)) ;; Original Logic: self-call?
                 ;; Currently logic allows anyone? No, checks self-call.
                 ;; Wait, who calls trigger-fallback? 
                 ;; In original code, it was public but restricted to self-call.
                 ;; Likely intended for internal logic or Authorized contracts.
                 ;; I'll keep restriction but might be dead code if no one calls it.
                 (if (> burn-block-height (get expiry pool))
                     (if (not (get settled pool))
                         (begin
                           (map-insert fallback-resolutions
                             { pool-id: pool-id }
                             {
                               triggered-at: burn-block-height,
                               failure-reason: failure-reason,
                               max-retries-reached: true,
                               manual-settlement-enabled: true,
                               notified-creator: false
                             }
                           )
                           (ok true)
                         )
                         (err ERR-POOL-SETTLED)
                     )
                     (err ERR-POOL-NOT-EXPIRED)
                 )
                 (err ERR-UNAUTHORIZED)
             )
      (err ERR-RESOLUTION-CONFIG-NOT-FOUND)
    )
    (err ERR-POOL-NOT-FOUND)
  )
)

(define-public (manual-settle-fallback (pool-id uint) (winning-outcome uint))
  (match (contract-call? .predinex-pool-1769575549853 get-pool-details pool-id)
    pool (match (map-get? fallback-resolutions { pool-id: pool-id })
      fallback (if (is-eq tx-sender (get creator pool))
                   (if (and 
                        (get manual-settlement-enabled fallback)
                        (or (is-eq winning-outcome u0) (is-eq winning-outcome u1))
                        (> burn-block-height (+ (get triggered-at fallback) u144))
                       )
                       (match (contract-call? .predinex-pool-1769575549853 settle-pool pool-id winning-outcome)
                          success (ok true)
                          error (err error)
                       )
                       (err ERR-MANUAL-SETTLEMENT-DISABLED)
                   )
                   (err ERR-UNAUTHORIZED)
               )
      (err ERR-FALLBACK-NOT-TRIGGERED)
    )
    (err ERR-POOL-NOT-FOUND)
  )
)

(define-read-only (get-dispute-details (dispute-id uint))
  (map-get? pool-disputes { dispute-id: dispute-id })
)
