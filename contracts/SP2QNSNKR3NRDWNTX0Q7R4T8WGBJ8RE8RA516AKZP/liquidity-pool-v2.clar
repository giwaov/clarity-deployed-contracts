;; Liquidity Pool Contract
;; Simplified peer-to-peer lending pool with dynamic rates

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u500))
(define-constant err-insufficient-liquidity (err u501))
(define-constant err-insufficient-balance (err u502))
(define-constant err-invalid-amount (err u503))
(define-constant err-pool-paused (err u504))

;; Pool parameters
(define-constant base-rate u500) ;; 5% base APY

;; Data Variables
(define-data-var pool-paused bool false)
(define-data-var borrow-nonce uint u0)

;; Data Maps
(define-map liquidity-providers
  { provider: principal }
  {
    deposited: uint,
    available: uint,
    earned: uint
  }
)

(define-map pool-borrows
  { borrower: principal, borrow-id: uint }
  {
    amount: uint,
    lender: principal,
    interest-rate: uint,
    borrow-block: uint,
    repaid: bool
  }
)

;; Read-only functions
(define-read-only (get-lp-info (provider principal))
  (default-to
    { deposited: u0, available: u0, earned: u0 }
    (map-get? liquidity-providers { provider: provider })
  )
)

(define-read-only (get-borrow-info (borrower principal) (borrow-id uint))
  (map-get? pool-borrows { borrower: borrower, borrow-id: borrow-id })
)

(define-read-only (get-current-rate)
  (ok base-rate)
)

;; Public functions

;; Deposit STX to pool
(define-public (deposit-to-pool (amount uint))
  (let
    (
      (lp-info (get-lp-info tx-sender))
    )
    (asserts! (not (var-get pool-paused)) err-pool-paused)
    (asserts! (> amount u0) err-invalid-amount)
    
    (map-set liquidity-providers
      { provider: tx-sender }
      {
        deposited: (+ (get deposited lp-info) amount),
        available: (+ (get available lp-info) amount),
        earned: (get earned lp-info)
      }
    )
    
    (ok amount)
  )
)

;; Borrow from specific lender
(define-public (borrow-from-pool (amount uint) (lender principal))
  (let
    (
      (borrow-id (var-get borrow-nonce))
      (current-rate (unwrap! (get-current-rate) err-invalid-amount))
      (lender-info (get-lp-info lender))
    )
    (asserts! (not (var-get pool-paused)) err-pool-paused)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= (get available lender-info) amount) err-insufficient-liquidity)
    
    (try! (stx-transfer? amount lender tx-sender))
    
    (map-set liquidity-providers
      { provider: lender }
      (merge lender-info { available: (- (get available lender-info) amount) })
    )
    
    (map-set pool-borrows
      { borrower: tx-sender, borrow-id: borrow-id }
      {
        amount: amount,
        lender: lender,
        interest-rate: current-rate,
        borrow-block: stacks-block-height,
        repaid: false
      }
    )
    
    (var-set borrow-nonce (+ borrow-id u1))
    (ok borrow-id)
  )
)

;; Repay pool borrow
(define-public (repay-pool-borrow (borrow-id uint))
  (let
    (
      (borrow-info (unwrap! (get-borrow-info tx-sender borrow-id) err-invalid-amount))
      (principal-amount (get amount borrow-info))
      (lender (get lender borrow-info))
      (blocks-elapsed (- stacks-block-height (get borrow-block borrow-info)))
      (interest-rate (get interest-rate borrow-info))
      (interest (/ (* (* principal-amount interest-rate) blocks-elapsed) u525600000))
      (total-repayment (+ principal-amount interest))
      (lender-info (get-lp-info lender))
    )
    (asserts! (not (get repaid borrow-info)) err-invalid-amount)
    
    (try! (stx-transfer? total-repayment tx-sender lender))
    
    (map-set liquidity-providers
      { provider: lender }
      {
        deposited: (get deposited lender-info),
        available: (+ (get available lender-info) principal-amount),
        earned: (+ (get earned lender-info) interest)
      }
    )
    
    (map-set pool-borrows
      { borrower: tx-sender, borrow-id: borrow-id }
      (merge borrow-info { repaid: true })
    )
    
    (ok total-repayment)
  )
)

;; Withdraw from pool
(define-public (withdraw-from-pool (amount uint))
  (let
    (
      (lp-info (get-lp-info tx-sender))
    )
    (asserts! (not (var-get pool-paused)) err-pool-paused)
    (asserts! (<= amount (get available lp-info)) err-insufficient-balance)
    
    (map-set liquidity-providers
      { provider: tx-sender }
      {
        deposited: (- (get deposited lp-info) amount),
        available: (- (get available lp-info) amount),
        earned: (get earned lp-info)
      }
    )
    
    (ok amount)
  )
)

;; Pause pool (owner only)
(define-public (pause-pool)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set pool-paused true)
    (ok true)
  )
)

;; Unpause pool (owner only)
(define-public (unpause-pool)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set pool-paused false)
    (ok true)
  )
)
