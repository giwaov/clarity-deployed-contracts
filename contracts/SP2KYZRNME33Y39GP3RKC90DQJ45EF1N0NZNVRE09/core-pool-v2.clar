;; STX DeFi Core Pool Contract
;; Handles lending and borrowing with shared liquidity pool
;; Mainnet deployment

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1001))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u1002))
(define-constant ERR_NO_POSITION (err u1003))
(define-constant ERR_INVALID_AMOUNT (err u1004))
(define-constant ERR_POOL_EMPTY (err u1005))
(define-constant ERR_POSITION_HEALTHY (err u1006))
(define-constant ERR_ALREADY_INITIALIZED (err u1007))
(define-constant ERR_NOT_INITIALIZED (err u1008))

;; Collateralization ratio: 150% (borrow up to 66.67% of collateral)
(define-constant COLLATERAL_RATIO u150)
;; Liquidation threshold: 120%
(define-constant LIQUIDATION_THRESHOLD u120)
;; Interest rate: 5% APY (stored as basis points, 500 = 5%)
(define-constant BORROW_INTEREST_RATE u500)
;; Blocks per year (approx 52,560 with 10-min blocks)
(define-constant BLOCKS_PER_YEAR u52560)
;; Protocol fee: 0.5%
(define-constant PROTOCOL_FEE u50)
;; Precision for calculations
(define-constant PRECISION u10000)

;; Data Variables
(define-data-var total-deposits uint u0)
(define-data-var total-borrows uint u0)
(define-data-var protocol-treasury uint u0)
(define-data-var is-initialized bool false)
(define-data-var last-update-block uint u0)

;; Data Maps
;; User lending positions
(define-map user-deposits principal uint)
;; User deposit block for interest calculation
(define-map user-deposit-block principal uint)
;; User borrow positions
(define-map user-borrows principal uint)
;; User borrow block for interest calculation
(define-map user-borrow-block principal uint)

;; Authorization check
(define-private (is-authorized)
  (is-eq tx-sender CONTRACT_OWNER)
)

;; Initialize the protocol
(define-public (initialize)
  (begin
    (asserts! (is-authorized) ERR_UNAUTHORIZED)
    (asserts! (not (var-get is-initialized)) ERR_ALREADY_INITIALIZED)
    (var-set is-initialized true)
    (var-set last-update-block block-height)
    (ok true)
  )
)

;; Read-only functions

;; Get user's deposit amount
(define-read-only (get-user-deposit (user principal))
  (default-to u0 (map-get? user-deposits user))
)

;; Get user's borrow amount
(define-read-only (get-user-borrow (user principal))
  (default-to u0 (map-get? user-borrows user))
)

;; Get user's maximum borrowable amount based on collateral
(define-read-only (get-max-borrow (user principal))
  (let (
    (user-dep (get-user-deposit user))
    (current-borrow (get-user-borrow user))
  )
    (if (is-eq user-dep u0)
      u0
      (- (/ (* user-dep u100) COLLATERAL_RATIO) current-borrow)
    )
  )
)

;; Calculate accrued interest for a borrow position
(define-read-only (get-accrued-interest (user principal))
  (let (
    (borrow-amount (get-user-borrow user))
    (borrow-block (default-to block-height (map-get? user-borrow-block user)))
    (blocks-elapsed (- block-height borrow-block))
    (interest-per-block (/ BORROW_INTEREST_RATE BLOCKS_PER_YEAR))
  )
    (/ (* (* borrow-amount interest-per-block) blocks-elapsed) PRECISION)
  )
)

;; Get total debt including interest
(define-read-only (get-total-debt (user principal))
  (+ (get-user-borrow user) (get-accrued-interest user))
)

;; Check if position is liquidatable
(define-read-only (is-liquidatable (user principal))
  (let (
    (user-dep (get-user-deposit user))
    (total-debt (get-total-debt user))
  )
    (if (is-eq total-debt u0)
      false
      (< (* user-dep u100) (* total-debt LIQUIDATION_THRESHOLD))
    )
  )
)

;; Get health factor (higher is healthier, < 100 means liquidatable)
(define-read-only (get-health-factor (user principal))
  (let (
    (user-dep (get-user-deposit user))
    (total-debt (get-total-debt user))
  )
    (if (is-eq total-debt u0)
      u9999  ;; Max health if no debt
      (/ (* user-dep u100) total-debt)
    )
  )
)

;; Get pool statistics
(define-read-only (get-pool-stats)
  {
    total-deposits: (var-get total-deposits),
    total-borrows: (var-get total-borrows),
    available-liquidity: (- (var-get total-deposits) (var-get total-borrows)),
    utilization-rate: (if (is-eq (var-get total-deposits) u0)
                        u0
                        (/ (* (var-get total-borrows) u100) (var-get total-deposits))),
    protocol-treasury: (var-get protocol-treasury)
  }
)

;; Public functions

;; Deposit STX as collateral / lending
(define-public (deposit (amount uint))
  (let (
    (current-dep (get-user-deposit tx-sender))
  )
    (asserts! (var-get is-initialized) ERR_NOT_INITIALIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update user deposit
    (map-set user-deposits tx-sender (+ current-dep amount))
    (map-set user-deposit-block tx-sender block-height)
    
    ;; Update total deposits
    (var-set total-deposits (+ (var-get total-deposits) amount))
    
    (ok {
      deposited: amount,
      total-deposit: (+ current-dep amount)
    })
  )
)

;; Borrow STX against collateral
(define-public (borrow (amount uint))
  (let (
    (borrower tx-sender)
    (current-dep (get-user-deposit tx-sender))
    (current-borrow (get-user-borrow tx-sender))
    (max-borrow (get-max-borrow tx-sender))
    (available-liquidity (- (var-get total-deposits) (var-get total-borrows)))
  )
    (asserts! (var-get is-initialized) ERR_NOT_INITIALIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> current-dep u0) ERR_NO_POSITION)
    (asserts! (<= amount max-borrow) ERR_INSUFFICIENT_COLLATERAL)
    (asserts! (<= amount available-liquidity) ERR_POOL_EMPTY)
    
    ;; Transfer STX to borrower (from contract to user)
    (try! (as-contract (stx-transfer? amount tx-sender borrower)))
    
    ;; Update user borrow
    (map-set user-borrows tx-sender (+ current-borrow amount))
    (map-set user-borrow-block tx-sender block-height)
    
    ;; Update total borrows
    (var-set total-borrows (+ (var-get total-borrows) amount))
    
    (ok {
      borrowed: amount,
      total-borrow: (+ current-borrow amount),
      health-factor: (get-health-factor tx-sender)
    })
  )
)

;; Repay borrowed STX
(define-public (repay (amount uint))
  (let (
    (current-borrow (get-user-borrow tx-sender))
    (total-debt (get-total-debt tx-sender))
    (repay-amount (if (> amount total-debt) total-debt amount))
    (principal-portion (if (> repay-amount (get-accrued-interest tx-sender))
                          (- repay-amount (get-accrued-interest tx-sender))
                          u0))
    (interest-portion (- repay-amount principal-portion))
  )
    (asserts! (var-get is-initialized) ERR_NOT_INITIALIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> current-borrow u0) ERR_NO_POSITION)
    
    ;; Transfer STX from borrower to contract
    (try! (stx-transfer? repay-amount tx-sender (as-contract tx-sender)))
    
    ;; Update protocol treasury with interest
    (var-set protocol-treasury (+ (var-get protocol-treasury) interest-portion))
    
    ;; Update user borrow (subtract principal portion only)
    (if (>= principal-portion current-borrow)
      (begin
        (map-delete user-borrows tx-sender)
        (map-delete user-borrow-block tx-sender)
      )
      (begin
        (map-set user-borrows tx-sender (- current-borrow principal-portion))
        (map-set user-borrow-block tx-sender block-height)
      )
    )
    
    ;; Update total borrows
    (var-set total-borrows (- (var-get total-borrows) (if (> principal-portion (var-get total-borrows)) 
                                                          (var-get total-borrows) 
                                                          principal-portion)))
    
    (ok {
      repaid: repay-amount,
      remaining-debt: (- total-debt repay-amount)
    })
  )
)

;; Withdraw deposited STX
(define-public (withdraw (amount uint))
  (let (
    (user tx-sender)
    (current-dep (get-user-deposit tx-sender))
    (current-borrow (get-user-borrow tx-sender))
    (available-liquidity (- (var-get total-deposits) (var-get total-borrows)))
  )
    (asserts! (var-get is-initialized) ERR_NOT_INITIALIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= amount current-dep) ERR_INSUFFICIENT_BALANCE)
    (asserts! (<= amount available-liquidity) ERR_POOL_EMPTY)
    
    ;; Check that withdrawal doesn't make position unhealthy
    (let (
      (new-dep (- current-dep amount))
      (required-collateral (/ (* current-borrow COLLATERAL_RATIO) u100))
    )
      (asserts! (>= new-dep required-collateral) ERR_INSUFFICIENT_COLLATERAL)
      
      ;; Transfer STX to user (from contract to user)
      (try! (as-contract (stx-transfer? amount tx-sender user)))
      
      ;; Update user deposit
      (if (is-eq new-dep u0)
        (begin
          (map-delete user-deposits tx-sender)
          (map-delete user-deposit-block tx-sender)
        )
        (map-set user-deposits tx-sender new-dep)
      )
      
      ;; Update total deposits
      (var-set total-deposits (- (var-get total-deposits) amount))
      
      (ok {
        withdrawn: amount,
        remaining-deposit: new-dep
      })
    )
  )
)

;; Liquidate an unhealthy position
(define-public (liquidate (user principal))
  (let (
    (liquidator tx-sender)
    (user-dep (get-user-deposit user))
    (user-total-debt (get-total-debt user))
    (liquidation-bonus (/ (* user-dep PROTOCOL_FEE) PRECISION))
    (collateral-to-seize (+ user-total-debt liquidation-bonus))
  )
    (asserts! (var-get is-initialized) ERR_NOT_INITIALIZED)
    (asserts! (is-liquidatable user) ERR_POSITION_HEALTHY)
    (asserts! (> user-dep u0) ERR_NO_POSITION)
    
    ;; Liquidator pays off the debt
    (try! (stx-transfer? user-total-debt liquidator (as-contract tx-sender)))
    
    ;; Liquidator receives collateral + bonus
    (let (
      (seize-amount (if (> collateral-to-seize user-dep) user-dep collateral-to-seize))
    )
      (try! (as-contract (stx-transfer? seize-amount tx-sender liquidator)))
      
      ;; Clear user's position
      (map-delete user-deposits user)
      (map-delete user-deposit-block user)
      (map-delete user-borrows user)
      (map-delete user-borrow-block user)
      
      ;; Update totals
      (var-set total-deposits (- (var-get total-deposits) user-dep))
      (var-set total-borrows (- (var-get total-borrows) (get-user-borrow user)))
      
      ;; Any remaining collateral stays in treasury
      (if (> user-dep seize-amount)
        (var-set protocol-treasury (+ (var-get protocol-treasury) (- user-dep seize-amount)))
        true
      )
      
      (ok {
        liquidated-user: user,
        debt-paid: user-total-debt,
        collateral-seized: seize-amount
      })
    )
  )
)

;; Admin: Withdraw protocol fees
(define-public (withdraw-treasury (amount uint))
  (begin
    (asserts! (is-authorized) ERR_UNAUTHORIZED)
    (asserts! (<= amount (var-get protocol-treasury)) ERR_INSUFFICIENT_BALANCE)
    
    (try! (as-contract (stx-transfer? amount tx-sender CONTRACT_OWNER)))
    (var-set protocol-treasury (- (var-get protocol-treasury) amount))
    
    (ok amount)
  )
)
