;; DeFi Lending Pool Contract
;; Main contract for handling deposits, borrows, repayments, and withdrawals

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u101))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_POSITION_NOT_FOUND (err u104))
(define-constant ERR_HEALTH_FACTOR_TOO_LOW (err u105))
(define-constant ERR_NO_COLLATERAL (err u106))
(define-constant ERR_OUTSTANDING_DEBT (err u107))

;; Collateral ratio: 75% (represented as 75 out of 100)
(define-constant COLLATERAL_RATIO u75)
(define-constant COLLATERAL_RATIO_DENOMINATOR u100)

;; Minimum health factor: 1.2 (represented as 120 out of 100)
(define-constant MIN_HEALTH_FACTOR u120)
(define-constant HEALTH_FACTOR_DENOMINATOR u100)

;; Interest precision (1e6 for 6 decimal places)
(define-constant INTEREST_PRECISION u1000000)

;; Data Variables
(define-data-var total-liquidity uint u0)
(define-data-var total-borrowed uint u0)
(define-data-var global-interest-index uint INTEREST_PRECISION)
(define-data-var last-update-block uint u0)
(define-data-var protocol-paused bool false)

;; Data Maps
(define-map user-positions
  principal
  {
    collateral: uint,
    borrowed: uint,
    interest-index: uint,
    last-interaction-block: uint
  }
)

(define-map pool-stats
  { stat-type: (string-ascii 20) }
  { value: uint }
)

;; Read-only functions

(define-read-only (get-user-position (user principal))
  (default-to
    { collateral: u0, borrowed: u0, interest-index: INTEREST_PRECISION, last-interaction-block: u0 }
    (map-get? user-positions user)
  )
)

(define-read-only (get-pool-liquidity)
  (var-get total-liquidity)
)

(define-read-only (get-total-borrowed)
  (var-get total-borrowed)
)

(define-read-only (get-utilization-rate)
  (let
    (
      (liquidity (var-get total-liquidity))
      (borrowed (var-get total-borrowed))
    )
    (if (is-eq liquidity u0)
      u0
      ;; Calculate utilization as percentage (borrowed / liquidity * 100)
      (/ (* borrowed u100) liquidity)
    )
  )
)

(define-read-only (get-global-interest-index)
  (var-get global-interest-index)
)

(define-read-only (calculate-max-borrow (user principal))
  (let
    (
      (position (get-user-position user))
      (collateral-value (get collateral position))
    )
    ;; Max borrow = collateral * COLLATERAL_RATIO / 100
    (/ (* collateral-value COLLATERAL_RATIO) COLLATERAL_RATIO_DENOMINATOR)
  )
)

(define-read-only (calculate-current-debt (user principal))
  (let
    (
      (position (get-user-position user))
      (borrowed (get borrowed position))
      (user-index (get interest-index position))
      (current-index (var-get global-interest-index))
    )
    (if (is-eq borrowed u0)
      u0
      ;; Debt = borrowed * (current-index / user-index)
      (/ (* borrowed current-index) user-index)
    )
  )
)

(define-read-only (get-health-factor (user principal))
  (let
    (
      (position (get-user-position user))
      (collateral (get collateral position))
      (current-debt (calculate-current-debt user))
    )
    (if (is-eq current-debt u0)
      u999999 ;; Essentially infinite health factor
      ;; Health factor = (collateral * COLLATERAL_RATIO / 100) / debt * 100
      (/ (* (/ (* collateral COLLATERAL_RATIO) COLLATERAL_RATIO_DENOMINATOR) HEALTH_FACTOR_DENOMINATOR) current-debt)
    )
  )
)

(define-read-only (is-protocol-paused)
  (var-get protocol-paused)
)

;; Private functions

(define-private (update-interest-index)
  (let
    (
      (blocks-elapsed (- block-height (var-get last-update-block)))
      (current-rate (contract-call? .interest-calculator get-current-rate))
    )
    (if (> blocks-elapsed u0)
      (let
        (
          ;; Calculate new interest based on blocks elapsed
          ;; Interest per block = rate / blocks-per-year (approximately 52560 blocks per year)
          (interest-per-block (/ current-rate u52560))
          (interest-multiplier (+ INTEREST_PRECISION (/ (* interest-per-block blocks-elapsed) u100)))
          (new-index (/ (* (var-get global-interest-index) interest-multiplier) INTEREST_PRECISION))
        )
        (var-set global-interest-index new-index)
        (var-set last-update-block block-height)
        true
      )
      true
    )
  )
)

;; Public functions

(define-public (deposit-collateral (amount uint))
  (begin
    (asserts! (not (var-get protocol-paused)) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Transfer STX from user to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update interest index
    (update-interest-index)
    
    ;; Update user position
    (let
      (
        (current-position (get-user-position tx-sender))
        (new-collateral (+ (get collateral current-position) amount))
      )
      (map-set user-positions tx-sender
        (merge current-position {
          collateral: new-collateral,
          last-interaction-block: block-height
        })
      )
      
      ;; Update total liquidity
      (var-set total-liquidity (+ (var-get total-liquidity) amount))
      
      (ok true)
    )
  )
)

(define-public (borrow-funds (amount uint))
  (begin
    (asserts! (not (var-get protocol-paused)) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Update interest index
    (update-interest-index)
    
    (let
      (
        (current-position (get-user-position tx-sender))
        (current-debt (calculate-current-debt tx-sender))
        (max-borrow (calculate-max-borrow tx-sender))
        (new-debt (+ current-debt amount))
      )
      ;; Check if user has enough collateral
      (asserts! (<= new-debt max-borrow) ERR_INSUFFICIENT_COLLATERAL)
      
      ;; Check if pool has enough liquidity
      (asserts! (<= amount (var-get total-liquidity)) ERR_INSUFFICIENT_LIQUIDITY)
      
      ;; Transfer borrowed amount to user
      (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
      
      ;; Update user position
      (map-set user-positions tx-sender
        (merge current-position {
          borrowed: new-debt,
          interest-index: (var-get global-interest-index),
          last-interaction-block: block-height
        })
      )
      
      ;; Update pool stats
      (var-set total-borrowed (+ (var-get total-borrowed) amount))
      (var-set total-liquidity (- (var-get total-liquidity) amount))
      
      ;; Update interest rates based on new utilization
      (try! (contract-call? .interest-calculator update-rates (get-utilization-rate)))
      
      (ok true)
    )
  )
)

(define-public (repay-loan (amount uint))
  (begin
    (asserts! (not (var-get protocol-paused)) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Update interest index
    (update-interest-index)
    
    (let
      (
        (current-position (get-user-position tx-sender))
        (current-debt (calculate-current-debt tx-sender))
        (repay-amount (if (<= amount current-debt) amount current-debt))
      )
      (asserts! (> current-debt u0) ERR_POSITION_NOT_FOUND)
      
      ;; Transfer repayment from user to contract
      (try! (stx-transfer? repay-amount tx-sender (as-contract tx-sender)))
      
      ;; Update user position
      (let
        (
          (new-debt (- current-debt repay-amount))
        )
        (map-set user-positions tx-sender
          (merge current-position {
            borrowed: new-debt,
            interest-index: (var-get global-interest-index),
            last-interaction-block: block-height
          })
        )
        
        ;; Update pool stats
        (var-set total-borrowed (- (var-get total-borrowed) repay-amount))
        (var-set total-liquidity (+ (var-get total-liquidity) repay-amount))
        
        ;; Update interest rates
        (try! (contract-call? .interest-calculator update-rates (get-utilization-rate)))
        
        (ok repay-amount)
      )
    )
  )
)

(define-public (withdraw-collateral (amount uint))
  (begin
    (asserts! (not (var-get protocol-paused)) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Update interest index
    (update-interest-index)
    
    (let
      (
        (current-position (get-user-position tx-sender))
        (collateral (get collateral current-position))
        (current-debt (calculate-current-debt tx-sender))
      )
      (asserts! (>= collateral amount) ERR_NO_COLLATERAL)
      
      ;; If user has debt, check health factor after withdrawal
      (if (> current-debt u0)
        (let
          (
            (new-collateral (- collateral amount))
            (max-borrow-after (/ (* new-collateral COLLATERAL_RATIO) COLLATERAL_RATIO_DENOMINATOR))
            (new-health-factor (/ (* max-borrow-after HEALTH_FACTOR_DENOMINATOR) current-debt))
          )
          (asserts! (>= new-health-factor MIN_HEALTH_FACTOR) ERR_HEALTH_FACTOR_TOO_LOW)
          true
        )
        true
      )
      
      ;; Transfer collateral back to user
      (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
      
      ;; Update user position
      (map-set user-positions tx-sender
        (merge current-position {
          collateral: (- collateral amount),
          last-interaction-block: block-height
        })
      )
      
      ;; Update total liquidity
      (var-set total-liquidity (- (var-get total-liquidity) amount))
      
      (ok true)
    )
  )
)

;; Admin functions

(define-public (toggle-protocol-pause)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set protocol-paused (not (var-get protocol-paused)))
    (ok (var-get protocol-paused))
  )
)
