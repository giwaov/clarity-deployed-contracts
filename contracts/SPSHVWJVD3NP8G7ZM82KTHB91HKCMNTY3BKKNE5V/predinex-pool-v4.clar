;; Predinex Pool - Prediction Market on Stacks
;; A simple prediction pool contract for binary outcomes

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-INVALID-AMOUNT (err u400))
(define-constant ERR-POOL-NOT-FOUND (err u404))
(define-constant ERR-POOL-SETTLED (err u409))
(define-constant ERR-INVALID-OUTCOME (err u422))
(define-constant ERR-NOT-SETTLED (err u412))
(define-constant ERR-ALREADY-CLAIMED (err u410))
(define-constant ERR-NO-WINNINGS (err u411))
(define-constant ERR-POOL-NOT-EXPIRED (err u413))
(define-constant ERR-INVALID-TITLE (err u420))
(define-constant ERR-INVALID-DESCRIPTION (err u421))
(define-constant ERR-INVALID-DURATION (err u423))

(define-constant FEE-PERCENT u2) ;; 2% fee

;; Data structures
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
    expiry: uint
  }
)

(define-map claims
  { pool-id: uint, user: principal }
  bool
)

(define-map user-bets
  { pool-id: uint, user: principal }
  {
    amount-a: uint,
    amount-b: uint,
    total-bet: uint
  }
)

(define-data-var pool-counter uint u0)
(define-data-var total-volume uint u0)

;; Create a new prediction pool
(define-public (create-pool (title (string-ascii 256)) (description (string-ascii 512)) (outcome-a (string-ascii 128)) (outcome-b (string-ascii 128)) (duration uint))
  (let ((pool-id (var-get pool-counter)))
    ;; Validation checks
    (asserts! (> (len title) u0) ERR-INVALID-TITLE)
    (asserts! (> (len description) u0) ERR-INVALID-DESCRIPTION)
    (asserts! (> (len outcome-a) u0) ERR-INVALID-OUTCOME)
    (asserts! (> (len outcome-b) u0) ERR-INVALID-OUTCOME)
    (asserts! (> duration u0) ERR-INVALID-DURATION)

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
        expiry: (+ burn-block-height duration)
      }
    )
    (var-set pool-counter (+ pool-id u1))
    (ok pool-id)
  )
)

;; Place a bet on a pool
(define-public (place-bet (pool-id uint) (outcome uint) (amount uint))
  (let ((pool (unwrap! (map-get? pools { pool-id: pool-id }) ERR-POOL-NOT-FOUND)))
    (asserts! (not (get settled pool)) ERR-POOL-SETTLED)
    (asserts! (or (is-eq outcome u0) (is-eq outcome u1)) ERR-INVALID-OUTCOME)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    (let ((pool-principal (as-contract tx-sender)))
        ;; Transfer STX from user to contract
        (try! (stx-transfer? amount tx-sender pool-principal))
    )

    ;; Update pool totals
    (if (is-eq outcome u0)
      (map-set pools
        { pool-id: pool-id }
        (merge pool { total-a: (+ (get total-a pool) amount) })
      )
      (map-set pools
        { pool-id: pool-id }
        (merge pool { total-b: (+ (get total-b pool) amount) })
      )
    )
    
    ;; Update user bet
    (let ((user-bet (default-to { amount-a: u0, amount-b: u0, total-bet: u0 } (map-get? user-bets { pool-id: pool-id, user: tx-sender }))))
      (map-set user-bets
        { pool-id: pool-id, user: tx-sender }
        (if (is-eq outcome u0)
          { amount-a: (+ (get amount-a user-bet) amount), amount-b: (get amount-b user-bet), total-bet: (+ (get total-bet user-bet) amount) }
          { amount-a: (get amount-a user-bet), amount-b: (+ (get amount-b user-bet) amount), total-bet: (+ (get total-bet user-bet) amount) }
        )
      )
    )
    
    ;; Update total volume
    (var-set total-volume (+ (var-get total-volume) amount))
    
    (ok true)
  )
)

;; Settle a pool with winning outcome
(define-public (settle-pool (pool-id uint) (winning-outcome uint))
  (let ((pool (unwrap! (map-get? pools { pool-id: pool-id }) ERR-POOL-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get creator pool)) ERR-UNAUTHORIZED)
    (asserts! (not (get settled pool)) ERR-POOL-SETTLED)
    (asserts! (or (is-eq winning-outcome u0) (is-eq winning-outcome u1)) ERR-INVALID-OUTCOME)
    
    ;; Transfer fee
    (let
      (
        (total-pool-balance (+ (get total-a pool) (get total-b pool)))
        (fee (/ (* total-pool-balance FEE-PERCENT) u100))
      )
      (if (> fee u0)
        (try! (as-contract (stx-transfer? fee tx-sender CONTRACT-OWNER)))
        true
      )
    )

    (map-set pools
      { pool-id: pool-id }
      (merge pool { settled: true, winning-outcome: (some winning-outcome), settled-at: (some burn-block-height) })
    )
    
    (ok true)
  )
)

;; Claim winnings from a settled pool
(define-public (claim-winnings (pool-id uint))
  (let 
    (
      (pool (unwrap! (map-get? pools { pool-id: pool-id }) ERR-POOL-NOT-FOUND))
      (user-bet (unwrap! (map-get? user-bets { pool-id: pool-id, user: tx-sender }) ERR-NO-WINNINGS))
      (winning-outcome (unwrap! (get winning-outcome pool) ERR-NOT-SETTLED))
    )
    (asserts! (get settled pool) ERR-NOT-SETTLED)
    (asserts! (is-none (map-get? claims { pool-id: pool-id, user: tx-sender })) ERR-ALREADY-CLAIMED)

    (let
      (
        (user-total-bet (get total-bet user-bet))
        (user-winning-bet (if (is-eq winning-outcome u0) (get amount-a user-bet) (get amount-b user-bet)))
        (pool-winning-total (if (is-eq winning-outcome u0) (get total-a pool) (get total-b pool)))
        (total-pool-balance (+ (get total-a pool) (get total-b pool)))
        (fee (/ (* total-pool-balance FEE-PERCENT) u100))
        (net-pool-balance (- total-pool-balance fee))
        (claimer tx-sender) ;; Capture the web3 user
      )
      
      (asserts! (> user-winning-bet u0) ERR-NO-WINNINGS)
      (asserts! (> pool-winning-total u0) ERR-NO-WINNINGS)

      (let
        (
          ;; Calculate share: (user_bet_on_winner * net_pool) / total_bet_on_winner
          (share (/ (* user-winning-bet net-pool-balance) pool-winning-total))
        )
        ;; Transfer share to user
        (try! (as-contract (stx-transfer? share tx-sender claimer)))
        
        ;; Mark as claimed
        (map-set claims { pool-id: pool-id, user: claimer } true)
        
        (ok true)
      )
    )
  )
)

;; Request refund if pool expired and not settled
(define-public (request-refund (pool-id uint))
  (let 
    (
      (pool (unwrap! (map-get? pools { pool-id: pool-id }) ERR-POOL-NOT-FOUND))
      (user-bet (unwrap! (map-get? user-bets { pool-id: pool-id, user: tx-sender }) ERR-NO-WINNINGS))
      (claimer tx-sender)
    )
    ;; Check expiry
    (asserts! (> burn-block-height (get expiry pool)) ERR-POOL-NOT-EXPIRED)
    ;; Check not settled
    (asserts! (not (get settled pool)) ERR-POOL-SETTLED)
    ;; Check not already claimed/refunded
    (asserts! (is-none (map-get? claims { pool-id: pool-id, user: tx-sender })) ERR-ALREADY-CLAIMED)

    (let
      (
        (refund-amount (get total-bet user-bet))
      )
      (asserts! (> refund-amount u0) ERR-NO-WINNINGS)

      ;; Transfer refund
      (try! (as-contract (stx-transfer? refund-amount tx-sender claimer)))

      ;; Mark as claimed
      (map-set claims { pool-id: pool-id, user: claimer } true)

      (ok true)
    )
  )
)

;; Read-only functions

;; Get pool details
(define-read-only (get-pool (pool-id uint))
  (map-get? pools { pool-id: pool-id })
)

;; Get user bet
(define-read-only (get-user-bet (pool-id uint) (user principal))
  (map-get? user-bets { pool-id: pool-id, user: user })
)

;; Get total pools created
(define-read-only (get-pool-count)
  (var-get pool-counter)
)

;; Get total volume
(define-read-only (get-total-volume)
  (var-get total-volume)
)
