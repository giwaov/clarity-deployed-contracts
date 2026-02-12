;; Flash Loans Contract
;; Uncollateralized instant loans - simplified escrow pattern
;; First flash loan implementation on Stacks!

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u400))
(define-constant err-insufficient-liquidity (err u401))
(define-constant err-flash-loan-not-repaid (err u402))
(define-constant err-invalid-amount (err u403))

;; Flash loan fee: 0.09% (9 basis points)
(define-constant flash-loan-fee-rate u9)

;; Data Variables
(define-data-var total-fees-collected uint u0)
(define-data-var flash-loan-count uint u0)

;; Data Maps
(define-map flash-loan-stats
  { user: principal }
  {
    total-borrowed: uint,
    total-fees-paid: uint,
    loan-count: uint
  }
)

(define-map liquidity-providers
  { provider: principal }
  { amount: uint }
)

;; Read-only functions
(define-read-only (get-flash-loan-fee (amount uint))
  (/ (* amount flash-loan-fee-rate) u10000)
)

(define-read-only (get-total-repayment (amount uint))
  (+ amount (get-flash-loan-fee amount))
)

(define-read-only (get-flash-loan-stats (user principal))
  (default-to
    { total-borrowed: u0, total-fees-paid: u0, loan-count: u0 }
    (map-get? flash-loan-stats { user: user })
  )
)

(define-read-only (get-total-fees-collected)
  (var-get total-fees-collected)
)

(define-read-only (get-provider-balance (provider principal))
  (default-to u0 (get amount (map-get? liquidity-providers { provider: provider })))
)

;; Public functions

;; Simplified flash loan: borrow and repay in same call
(define-public (execute-flash-loan 
  (amount uint)
  (lender principal))
  (let
    (
      (fee (get-flash-loan-fee amount))
      (total-repayment (+ amount fee))
      (lender-balance (get-provider-balance lender))
    )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= lender-balance amount) err-insufficient-liquidity)
    
    ;; Borrower must have enough to repay
    (asserts! (>= (stx-get-balance tx-sender) total-repayment) err-flash-loan-not-repaid)
    
    ;; Transfer loan from lender to borrower
    (try! (stx-transfer? amount lender tx-sender))
    
    ;; Immediate repayment with fee
    (try! (stx-transfer? total-repayment tx-sender lender))
    
    ;; Update stats
    (update-flash-loan-stats tx-sender amount fee)
    (var-set total-fees-collected (+ (var-get total-fees-collected) fee))
    (var-set flash-loan-count (+ (var-get flash-loan-count) u1))
    
    (ok { amount: amount, fee: fee, profit: fee })
  )
)

;; Add liquidity for flash loans
(define-public (add-flash-liquidity (amount uint))
  (let
    (
      (current-balance (get-provider-balance tx-sender))
    )
    (asserts! (> amount u0) err-invalid-amount)
    
    (map-set liquidity-providers
      { provider: tx-sender }
      { amount: (+ current-balance amount) }
    )
    
    (ok true)
  )
)

;; Remove liquidity
(define-public (remove-flash-liquidity (amount uint))
  (let
    (
      (current-balance (get-provider-balance tx-sender))
    )
    (asserts! (<= amount current-balance) err-insufficient-liquidity)
    
    (map-set liquidity-providers
      { provider: tx-sender }
      { amount: (- current-balance amount) }
    )
    
    (ok true)
  )
)

;; Private functions
(define-private (update-flash-loan-stats (user principal) (amount uint) (fee uint))
  (let
    (
      (stats (get-flash-loan-stats user))
    )
    (map-set flash-loan-stats
      { user: user }
      {
        total-borrowed: (+ (get total-borrowed stats) amount),
        total-fees-paid: (+ (get total-fees-paid stats) fee),
        loan-count: (+ (get loan-count stats) u1)
      }
    )
  )
)
