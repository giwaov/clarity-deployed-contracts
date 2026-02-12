;; ============================================================================
;; FEES.CLAR - Stability Fee & Fee Accounting System
;; ============================================================================
;; Manages stability fees (interest on debt), mint/redeem fees, and 
;; liquidation penalties. Uses block-based time for fee accrual.
;; All fees are calculated with fixed-point precision.
;; ============================================================================

;; ============================================================================
;; CONSTANTS
;; ============================================================================

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u4000))
(define-constant ERR-VAULT-NOT-FOUND (err u4001))
(define-constant ERR-INVALID-PARAMETER (err u4002))
(define-constant ERR-SYSTEM-PAUSED (err u4003))
(define-constant ERR-OVERFLOW (err u4004))
(define-constant ERR-ZERO-AMOUNT (err u4005))

;; Precision constants
(define-constant BPS u10000)                        ;; Basis points scale (100% = 10000)
(define-constant RATE-PRECISION u1000000000000)     ;; 1e12 for rate calculations
(define-constant BLOCKS-PER-YEAR u52560)            ;; ~365.25 days * 144 blocks/day (10 min blocks)

;; Default fee parameters
(define-constant DEFAULT-STABILITY-FEE-APR u500)    ;; 5% APR in BPS
(define-constant DEFAULT-MINT-FEE-BPS u50)          ;; 0.5% mint fee
(define-constant DEFAULT-REDEEM-FEE-BPS u50)        ;; 0.5% redeem fee
(define-constant DEFAULT-LIQUIDATION-PENALTY u1000) ;; 10% liquidation penalty

;; ============================================================================
;; DATA STORAGE
;; ============================================================================

;; Global fee parameters
(define-data-var stability-fee-apr uint DEFAULT-STABILITY-FEE-APR)
(define-data-var mint-fee-bps uint DEFAULT-MINT-FEE-BPS)
(define-data-var redeem-fee-bps uint DEFAULT-REDEEM-FEE-BPS)
(define-data-var liquidation-penalty-bps uint DEFAULT-LIQUIDATION-PENALTY)

;; Per-vault fee state
;; Tracks accrued fees and last update block for each vault
(define-map vault-fee-state 
  uint  ;; vault-id
  {
    accrued-fees: uint,           ;; Total accrued stability fees
    last-accrual-block: uint,     ;; Block when fees were last accrued
    total-fees-paid: uint,        ;; Historical total fees paid
    debt-at-last-accrual: uint    ;; Debt amount at last accrual (for calculation)
  })

;; Global fee collection
(define-data-var total-fees-collected uint u0)
(define-data-var total-stability-fees uint u0)
(define-data-var total-mint-fees uint u0)
(define-data-var total-redeem-fees uint u0)
(define-data-var total-liquidation-penalties uint u0)

;; Fee collector address
(define-data-var fee-collector principal tx-sender)

;; Admin
(define-data-var contract-admin principal tx-sender)

;; ============================================================================
;; FEE ACCRUAL FUNCTIONS
;; ============================================================================

;; Initialize fee state for a new vault
(define-public (init-vault-fee-state (vault-id uint))
  (begin
    ;; Anyone can init, but typically called by vaults contract
    (map-set vault-fee-state vault-id {
      accrued-fees: u0,
      last-accrual-block: block-height,
      total-fees-paid: u0,
      debt-at-last-accrual: u0
    })
    (print {event: "vault-fee-initialized", vault-id: vault-id, block: block-height})
    (ok true)))

;; Accrue stability fees for a vault
;; This should be called before any vault operation that affects debt
;; @param vault-id: The vault identifier
;; @param current-debt: The current debt amount (from vaults contract)
;; @returns: The new accrued fees amount
(define-public (accrue (vault-id uint) (current-debt uint))
  (let (
    (fee-state (unwrap! (map-get? vault-fee-state vault-id) ERR-VAULT-NOT-FOUND))
    (last-block (get last-accrual-block fee-state))
    (blocks-elapsed (- block-height last-block))
    (debt-for-calc (get debt-at-last-accrual fee-state))
    (existing-accrued (get accrued-fees fee-state))
    (new-fees (calculate-stability-fee debt-for-calc blocks-elapsed))
    (total-accrued (+ existing-accrued new-fees))
  )
    ;; Update state
    (map-set vault-fee-state vault-id {
      accrued-fees: total-accrued,
      last-accrual-block: block-height,
      total-fees-paid: (get total-fees-paid fee-state),
      debt-at-last-accrual: current-debt
    })
    
    ;; Update global tracking
    (var-set total-stability-fees (+ (var-get total-stability-fees) new-fees))
    
    (print {
      event: "fees-accrued",
      vault-id: vault-id,
      new-fees: new-fees,
      total-accrued: total-accrued,
      blocks-elapsed: blocks-elapsed,
      debt: debt-for-calc
    })
    
    (ok total-accrued)))

;; Calculate stability fee based on debt and time
;; Uses simple interest: fee = principal * rate * time
;; Rate is per-block derived from APR
(define-read-only (calculate-stability-fee (principal uint) (blocks uint))
  (if (or (is-eq principal u0) (is-eq blocks u0))
      u0
      (let (
        (apr (var-get stability-fee-apr))
        ;; Convert APR to per-block rate
        ;; rate_per_block = APR / BPS / BLOCKS_PER_YEAR
        ;; fee = principal * rate_per_block * blocks
        ;; To avoid precision loss: fee = principal * APR * blocks / (BPS * BLOCKS_PER_YEAR)
        (numerator (* (* principal apr) blocks))
        (denominator (* BPS BLOCKS-PER-YEAR))
      )
        (/ numerator denominator))))

;; Calculate compound interest (optional - more accurate but complex)
;; Uses approximation: (1 + r)^n ~= 1 + n*r for small r
(define-read-only (calculate-compound-fee (principal uint) (blocks uint))
  ;; For simplicity, using simple interest
  ;; Can be upgraded to compound formula later
  (calculate-stability-fee principal blocks))

;; ============================================================================
;; MINT/REDEEM FEE CALCULATIONS
;; ============================================================================

;; Calculate mint fee on a stablecoin amount
;; @param amount: Amount of stablecoins being minted
;; @returns: Fee amount to collect
(define-read-only (calculate-mint-fee (amount uint))
  (/ (* amount (var-get mint-fee-bps)) BPS))

;; Calculate redeem fee on a stablecoin amount
;; @param amount: Amount of stablecoins being redeemed/repaid
;; @returns: Fee amount to collect
(define-read-only (calculate-redeem-fee (amount uint))
  (/ (* amount (var-get redeem-fee-bps)) BPS))

;; Calculate amount after mint fee deduction
(define-read-only (amount-after-mint-fee (amount uint))
  (let ((fee (calculate-mint-fee amount)))
    (- amount fee)))

;; Calculate total amount needed including redeem fee
(define-read-only (amount-with-redeem-fee (amount uint))
  (let ((fee (calculate-redeem-fee amount)))
    (+ amount fee)))

;; ============================================================================
;; LIQUIDATION PENALTY CALCULATIONS
;; ============================================================================

;; Calculate liquidation penalty on collateral
;; @param collateral-value: Value of collateral being seized
;; @returns: Penalty amount (bonus for liquidator)
(define-read-only (calculate-liquidation-penalty (collateral-value uint))
  (/ (* collateral-value (var-get liquidation-penalty-bps)) BPS))

;; Calculate total collateral liquidator receives (collateral + penalty discount)
(define-read-only (calculate-liquidation-collateral (debt-to-cover uint) (collateral-price uint))
  (let (
    (base-collateral (/ (* debt-to-cover RATE-PRECISION) collateral-price))
    (penalty-bonus (/ (* base-collateral (var-get liquidation-penalty-bps)) BPS))
  )
    (+ base-collateral penalty-bonus)))

;; ============================================================================
;; FEE PAYMENT & COLLECTION
;; ============================================================================

;; Record fee payment from a vault
(define-public (record-fee-payment (vault-id uint) (amount uint) (fee-type (string-ascii 20)))
  (let (
    (fee-state (unwrap! (map-get? vault-fee-state vault-id) ERR-VAULT-NOT-FOUND))
    (current-accrued (get accrued-fees fee-state))
  )
    ;; Ensure payment doesn't exceed accrued
    (asserts! (>= current-accrued amount) (err u4006))
    
    ;; Update vault fee state
    (map-set vault-fee-state vault-id {
      accrued-fees: (- current-accrued amount),
      last-accrual-block: (get last-accrual-block fee-state),
      total-fees-paid: (+ (get total-fees-paid fee-state) amount),
      debt-at-last-accrual: (get debt-at-last-accrual fee-state)
    })
    
    ;; Update global collection
    (var-set total-fees-collected (+ (var-get total-fees-collected) amount))
    
    (print {
      event: "fee-payment-recorded",
      vault-id: vault-id,
      amount: amount,
      fee-type: fee-type
    })
    (ok amount)))

;; Record mint fee collection
(define-public (record-mint-fee (amount uint))
  (begin
    (var-set total-mint-fees (+ (var-get total-mint-fees) amount))
    (var-set total-fees-collected (+ (var-get total-fees-collected) amount))
    (print {event: "mint-fee-collected", amount: amount})
    (ok amount)))

;; Record redeem fee collection
(define-public (record-redeem-fee (amount uint))
  (begin
    (var-set total-redeem-fees (+ (var-get total-redeem-fees) amount))
    (var-set total-fees-collected (+ (var-get total-fees-collected) amount))
    (print {event: "redeem-fee-collected", amount: amount})
    (ok amount)))

;; Record liquidation penalty
(define-public (record-liquidation-penalty (amount uint) (vault-id uint))
  (begin
    (var-set total-liquidation-penalties (+ (var-get total-liquidation-penalties) amount))
    (print {event: "liquidation-penalty-recorded", vault-id: vault-id, amount: amount})
    (ok amount)))

;; ============================================================================
;; READ-ONLY FUNCTIONS
;; ============================================================================

;; Get fee state for a vault
(define-read-only (get-fee-state (vault-id uint))
  (map-get? vault-fee-state vault-id))

;; Get pending (unaccrued) fees for a vault
(define-read-only (get-pending-fees (vault-id uint) (current-debt uint))
  (match (map-get? vault-fee-state vault-id)
    fee-state 
      (let (
        (blocks-elapsed (- block-height (get last-accrual-block fee-state)))
        (debt (get debt-at-last-accrual fee-state))
      )
        (+ (get accrued-fees fee-state) (calculate-stability-fee debt blocks-elapsed)))
    u0))

;; Get total debt including accrued fees
(define-read-only (get-total-debt (vault-id uint) (principal-debt uint))
  (+ principal-debt (get-pending-fees vault-id principal-debt)))

;; Get global fee statistics
(define-read-only (get-global-fee-stats)
  {
    total-collected: (var-get total-fees-collected),
    stability-fees: (var-get total-stability-fees),
    mint-fees: (var-get total-mint-fees),
    redeem-fees: (var-get total-redeem-fees),
    liquidation-penalties: (var-get total-liquidation-penalties)
  })

;; Get current fee parameters
(define-read-only (get-fee-params)
  {
    stability-fee-apr: (var-get stability-fee-apr),
    mint-fee-bps: (var-get mint-fee-bps),
    redeem-fee-bps: (var-get redeem-fee-bps),
    liquidation-penalty-bps: (var-get liquidation-penalty-bps),
    fee-collector: (var-get fee-collector),
    bps-scale: BPS,
    blocks-per-year: BLOCKS-PER-YEAR
  })

;; ============================================================================
;; PARAMETER MANAGEMENT (Admin Only)
;; ============================================================================

;; Set stability fee APR (in basis points)
(define-public (set-stability-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)
    ;; Max 100% APR
    (asserts! (<= new-fee BPS) ERR-INVALID-PARAMETER)
    
    (var-set stability-fee-apr new-fee)
    (print {event: "stability-fee-updated", fee-bps: new-fee})
    (ok true)))

;; Set mint fee (in basis points)
(define-public (set-mint-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)
    ;; Max 10% mint fee
    (asserts! (<= new-fee u1000) ERR-INVALID-PARAMETER)
    
    (var-set mint-fee-bps new-fee)
    (print {event: "mint-fee-updated", fee-bps: new-fee})
    (ok true)))

;; Set redeem fee (in basis points)
(define-public (set-redeem-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)
    ;; Max 10% redeem fee
    (asserts! (<= new-fee u1000) ERR-INVALID-PARAMETER)
    
    (var-set redeem-fee-bps new-fee)
    (print {event: "redeem-fee-updated", fee-bps: new-fee})
    (ok true)))

;; Set liquidation penalty (in basis points)
(define-public (set-liquidation-penalty (new-penalty uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)
    ;; Min 1%, Max 50% penalty
    (asserts! (and (>= new-penalty u100) (<= new-penalty u5000)) ERR-INVALID-PARAMETER)
    
    (var-set liquidation-penalty-bps new-penalty)
    (print {event: "liquidation-penalty-updated", penalty-bps: new-penalty})
    (ok true)))

;; Set fee collector address
(define-public (set-fee-collector (new-collector principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)
    
    (var-set fee-collector new-collector)
    (print {event: "fee-collector-updated", collector: new-collector})
    (ok true)))

;; Batch update all fee parameters
(define-public (set-all-params 
  (new-stability-fee uint)
  (new-mint-fee uint) 
  (new-redeem-fee uint)
  (new-liq-penalty uint))
  (begin
    (try! (set-stability-fee new-stability-fee))
    (try! (set-mint-fee new-mint-fee))
    (try! (set-redeem-fee new-redeem-fee))
    (try! (set-liquidation-penalty new-liq-penalty))
    (ok true)))

;; Transfer admin rights
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)
    (var-set contract-admin new-admin)
    (print {event: "admin-transferred", new-admin: new-admin})
    (ok true)))

;; ============================================================================
;; HELPER FUNCTIONS
;; ============================================================================

;; Apply fee to an amount (deduct fee)
(define-read-only (apply-fee-deduction (amount uint) (fee-bps uint))
  (- amount (/ (* amount fee-bps) BPS)))

;; Calculate fee on an amount
(define-read-only (calculate-fee (amount uint) (fee-bps uint))
  (/ (* amount fee-bps) BPS))
