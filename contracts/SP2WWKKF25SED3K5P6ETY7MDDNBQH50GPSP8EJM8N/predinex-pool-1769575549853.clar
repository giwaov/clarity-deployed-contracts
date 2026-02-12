;; ============================================
;; PREDINEX POOL - CORE CONTRACT
;; ============================================
;; Core pool management and betting logic
;; Language: Clarity 2
;; ============================================

;; Constants & Errors
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED u401)
(define-constant ERR-INVALID-AMOUNT u400)
(define-constant ERR-POOL-NOT-FOUND u404)
(define-constant ERR-POOL-SETTLED u409)
(define-constant ERR-INVALID-OUTCOME u422)
(define-constant ERR-NOT-SETTLED u412)
(define-constant ERR-ALREADY-CLAIMED u410)
(define-constant ERR-NO-WINNINGS u411)
(define-constant ERR-POOL-NOT-EXPIRED u413)
(define-constant ERR-INVALID-TITLE u420)
(define-constant ERR-ORACLE-NOT-FOUND u430)

(define-constant FEE-PERCENT u2) ;; 2% fee
(define-constant MIN-BET-AMOUNT u10000) ;; 0.01 STX
(define-constant RESOLUTION-FEE-PERCENT u5)

;; Data Structures
(define-map pools
  { pool-id: uint }
  {
    creator: principal,
    title: (string-ascii 256),
    description: (string-ascii 512),
    outcome-a-name: (string-ascii 128),
    outcome-b-name: (string-ascii 128),
    total-a: uint,
    total-b: uint,
    settled: bool,
    winning-outcome: (optional uint),
    created-at: uint,
    settled-at: (optional uint),
    expiry: uint,
    outcome-count: uint,
    dispute-period: uint
  }
)

(define-map user-bets
  { pool-id: uint, user: principal }
  {
    amount-a: uint,
    amount-b: uint,
    total-bet: uint,
    first-bet-block: uint
  }
)

(define-map claims
  { pool-id: uint, user: principal }
  bool
)

;; Fee Structures
(define-map resolution-fees
  { pool-id: uint }
  {
    total-fee: uint,
    oracle-fees: uint,
    platform-fee: uint,
    is-refunded: bool,
    refund-recipient: (optional principal)
  }
)

(define-map oracle-fee-claims
  { provider-id: uint, pool-id: uint }
  {
    fee-amount: uint,
    is-claimed: bool,
    claimed-at: (optional uint)
  }
)

(define-map admins
  { admin: principal }
  bool
)

;; State Variables
(define-data-var pool-counter uint u1)
(define-data-var total-volume uint u0)
(define-data-var authorized-resolution-engine principal tx-sender)

;; Private Helpers

(define-private (is-admin (user principal))
  (default-to false (map-get? admins { admin: user }))
)

;; Registry Helper
(define-private (get-provider-id-by-address (provider-address principal))
  (contract-call? .predinex-oracle-registry-1769574272753 get-provider-id-by-address provider-address)
)

;; Public Functions

(define-public (create-pool (title (string-ascii 256)) (description (string-ascii 512)) (outcome-a (string-ascii 128)) (outcome-b (string-ascii 128)) (duration uint))
  (let ((pool-id (var-get pool-counter)))
    (if (and 
          (> (len title) u0) (<= (len title) u256)
          (> (len description) u0) (<= (len description) u512)
          (> (len outcome-a) u0) (<= (len outcome-a) u128)
          (> (len outcome-b) u0) (<= (len outcome-b) u128)
          (> duration u0)
        )
        (begin
          (map-insert pools
            { pool-id: pool-id }
            {
              creator: tx-sender,
              title: title,
              description: description,
              outcome-a-name: outcome-a,
              outcome-b-name: outcome-b,
              total-a: u0,
              total-b: u0,
              settled: false,
              winning-outcome: none,
              created-at: burn-block-height,
              settled-at: none,
              expiry: (+ burn-block-height duration),
              outcome-count: u2,
              dispute-period: u100
            }
          )
          ;; Initialize incentives via external contract
          ;; Note: liquidity-incentives contract must allow this call
          (unwrap! (as-contract (contract-call? .liquidity-incentives-1769574671620 initialize-pool-incentives pool-id)) (err u500))
          
          (var-set pool-counter (+ pool-id u1))
          (ok pool-id)
        )
        (err ERR-INVALID-TITLE)
    )
  )
)

(define-public (place-bet (pool-id uint) (outcome uint) (amount uint))
  (match (map-get? pools { pool-id: pool-id })
    pool (if (and 
               (not (get settled pool))
               (or (is-eq outcome u0) (is-eq outcome u1))
               (>= amount MIN-BET-AMOUNT)
               (< burn-block-height (get expiry pool))
             )
             (let ((pool-principal (as-contract tx-sender)))
               (match (stx-transfer? amount tx-sender pool-principal)
                 success (begin
                   ;; Update pool totals
                   (map-set pools 
                     { pool-id: pool-id } 
                     (if (is-eq outcome u0)
                         (merge pool { total-a: (+ (get total-a pool) amount) })
                         (merge pool { total-b: (+ (get total-b pool) amount) })
                     )
                   )
                   ;; Update user bet
                   (let ((user-bet (default-to 
                                     { amount-a: u0, amount-b: u0, total-bet: u0, first-bet-block: burn-block-height } 
                                     (map-get? user-bets { pool-id: pool-id, user: tx-sender }))))
                     (map-set user-bets
                       { pool-id: pool-id, user: tx-sender }
                       (if (is-eq outcome u0)
                         (merge user-bet { amount-a: (+ (get amount-a user-bet) amount), total-bet: (+ (get total-bet user-bet) amount) })
                         (merge user-bet { amount-b: (+ (get amount-b user-bet) amount), total-bet: (+ (get total-bet user-bet) amount) })
                       )
                     )
                   )
                   
                   ;; Call external incentive contract
                   ;; We ignore the result (bonus amount) to not block bet if incentives fail/are maxed
                   (match (contract-call? .liquidity-incentives-1769574671620 record-bet-and-calculate-early-bird pool-id tx-sender amount)
                     bonus-ok true
                     bonus-err true ;; Log or handle error? For now, we proceed.
                   )

                   (var-set total-volume (+ (var-get total-volume) amount))
                   (ok true)
                 )
                 error (err error)
               )
             )
             (err ERR-INVALID-OUTCOME)
         )
    (err ERR-POOL-NOT-FOUND)
  )
)

(define-public (settle-pool (pool-id uint) (winning-outcome uint))
  (match (map-get? pools { pool-id: pool-id })
    pool (if (or 
               (is-eq tx-sender (get creator pool))
               (is-eq tx-sender (var-get authorized-resolution-engine))
             )
             (if (not (get settled pool))
                 (if (or (is-eq winning-outcome u0) (is-eq winning-outcome u1))
                     (let (
                       (total-pool-balance (+ (get total-a pool) (get total-b pool)))
                       (fee (/ (* total-pool-balance FEE-PERCENT) u100))
                     )
                       (match (if (> fee u0) (as-contract (stx-transfer? fee tx-sender CONTRACT-OWNER)) (ok true))
                         success (begin
                           (map-set pools
                             { pool-id: pool-id }
                             (merge pool { settled: true, winning-outcome: (some winning-outcome), settled-at: (some burn-block-height) })
                           )
                           (ok true)
                         )
                         error (err error)
                       )
                     )
                     (err ERR-INVALID-OUTCOME)
                 )
                 (err ERR-POOL-SETTLED)
             )
             (err ERR-UNAUTHORIZED)
         )
    (err ERR-POOL-NOT-FOUND)
  )
)

(define-public (claim-winnings (pool-id uint))
  (match (map-get? pools { pool-id: pool-id })
    pool (match (map-get? user-bets { pool-id: pool-id, user: tx-sender })
      user-bet (match (get winning-outcome pool)
        winning-outcome (if (get settled pool)
            (if (is-none (map-get? claims { pool-id: pool-id, user: tx-sender }))
                (let
                  (
                    (user-winning-bet (if (is-eq winning-outcome u0) (get amount-a user-bet) (get amount-b user-bet)))
                    (pool-winning-total (if (is-eq winning-outcome u0) (get total-a pool) (get total-b pool)))
                    (total-pool-balance (+ (get total-a pool) (get total-b pool)))
                    (fee (/ (* total-pool-balance FEE-PERCENT) u100))
                    (net-pool-balance (- total-pool-balance fee))
                    (user tx-sender)
                  )
                  (if (and (> user-winning-bet u0) (> pool-winning-total u0))
                      (let
                        (
                          (base-share (/ (* user-winning-bet net-pool-balance) pool-winning-total))
                        )
                        (match (as-contract (stx-transfer? base-share tx-sender user))
                          success (begin
                            (map-set claims { pool-id: pool-id, user: tx-sender } true)
                            (ok base-share)
                          )
                          error (err error)
                        )
                      )
                      (err ERR-NO-WINNINGS)
                  )
                )
                (err ERR-ALREADY-CLAIMED)
            )
            (err ERR-NOT-SETTLED)
        )
        (err ERR-NOT-SETTLED)
      )
      (err ERR-NO-WINNINGS)
    )
    (err ERR-POOL-NOT-FOUND)
  )
)

(define-public (set-admin (admin principal) (status bool))
  (if (is-eq tx-sender CONTRACT-OWNER)
      (begin
        (map-set admins { admin: admin } status)
        (ok true)
      )
      (err ERR-UNAUTHORIZED)
  )
)

(define-public (set-authorized-resolution-engine (engine principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) (err ERR-UNAUTHORIZED))
    (var-set authorized-resolution-engine engine)
    (ok true)
  )
)

;; Fee management functions (kept for legacy support or future resolution integration)

(define-public (collect-resolution-fee (pool-id uint))
  (match (map-get? pools { pool-id: pool-id })
    pool (let (
           (total-pool-value (+ (get total-a pool) (get total-b pool)))
           (resolution-fee (/ (* total-pool-value RESOLUTION-FEE-PERCENT) u1000))
           (oracle-fee-portion (/ (* resolution-fee u80) u100))
           (platform-fee-portion (- resolution-fee oracle-fee-portion))
         )
            (if (is-eq tx-sender (as-contract tx-sender))
                (begin
                  (map-insert resolution-fees
                    { pool-id: pool-id }
                    {
                      total-fee: resolution-fee,
                      oracle-fees: oracle-fee-portion,
                      platform-fee: platform-fee-portion,
                      is-refunded: false,
                      refund-recipient: none
                    }
                  )
                  (match (as-contract (stx-transfer? platform-fee-portion tx-sender CONTRACT-OWNER))
                    success (ok resolution-fee)
                    error (err error)
                  )
                )
                (err ERR-UNAUTHORIZED)
            )
         )
    (err ERR-POOL-NOT-FOUND)
  )
)

(define-private (distribute-fee-to-oracle (provider-id uint) (fee-data { pool-id: uint, fee-amount: uint }))
  (begin
    (map-insert oracle-fee-claims
      { provider-id: provider-id, pool-id: (get pool-id fee-data) }
      {
        fee-amount: (get fee-amount fee-data),
        is-claimed: false,
        claimed-at: none
      }
    )
    fee-data
  )
)

(define-public (distribute-oracle-fees (pool-id uint) (oracle-providers-list (list 5 uint)))
  (match (map-get? resolution-fees { pool-id: pool-id })
    fee-info (let (
               (oracle-fees (get oracle-fees fee-info))
               (num-oracles (len oracle-providers-list))
               (fee-per-oracle (if (> num-oracles u0) (/ oracle-fees num-oracles) u0))
             )
               (if (is-eq tx-sender (as-contract tx-sender))
                   (begin
                     (fold distribute-fee-to-oracle oracle-providers-list { pool-id: pool-id, fee-amount: fee-per-oracle })
                     (ok true)
                   )
                   (err ERR-UNAUTHORIZED)
               )
             )
    (err ERR-POOL-NOT-FOUND)
  )
)

(define-public (claim-oracle-fee (pool-id uint))
  (match (get-provider-id-by-address tx-sender)
    provider-id (match (map-get? oracle-fee-claims { provider-id: provider-id, pool-id: pool-id })
      fee-claim (if (not (get is-claimed fee-claim))
                    (let ((fee-amount (get fee-amount fee-claim)) (recipient tx-sender))
                      (match (as-contract (stx-transfer? fee-amount tx-sender recipient))
                        success (begin
                          (map-set oracle-fee-claims
                            { provider-id: provider-id, pool-id: pool-id }
                            (merge fee-claim {
                              is-claimed: true,
                              claimed-at: (some burn-block-height)
                            })
                          )
                          (ok fee-amount)
                        )
                        error (err error)
                      )
                    )
                    (err ERR-ALREADY-CLAIMED)
                )
      (err ERR-NO-WINNINGS)
    )
    (err ERR-ORACLE-NOT-FOUND)
  )
)

;; Read-only getters
(define-read-only (get-pool-details (pool-id uint))
  (map-get? pools { pool-id: pool-id })
)

(define-read-only (get-user-bet (pool-id uint) (user principal))
  (map-get? user-bets { pool-id: pool-id, user: user })
)

(define-read-only (get-creation-data (pool-id uint))
  (map-get? pools { pool-id: pool-id })
)