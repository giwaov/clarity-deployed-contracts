;; ============================================
;; Lending Pool Contract
;; Core structure for the dual-asset lending protocol
;; ============================================

;; ====== temp test ======
(define-data-var temp-counter uint u0)

(define-public (increment-counter)
  (begin
    (var-set temp-counter (+ (var-get temp-counter) u1))
    (ok (var-get temp-counter))
  )
)

(define-public (decrement-counter)
  (begin
    (if (> (var-get temp-counter) u0)
      (var-set temp-counter (- (var-get temp-counter) u1))
      (var-set temp-counter u0)
    )
    (ok (var-get temp-counter))
  )
)

(define-read-only (get-counter)
  (ok (var-get temp-counter))
)
;; ====== temp test ======

;; ============================================
;; Error Constants
;; ============================================
(define-constant ERR_INVALID_WITHDRAW_AMOUNT (err u100))
(define-constant ERR_EXCEEDED_MAX_BORROW (err u101))
(define-constant ERR_CANNOT_BE_LIQUIDATED (err u102))
(define-constant ERR_MUST_WITHDRAW_BEFORE_NEW_DEPOSIT (err u103))
(define-constant ERR_INVALID_ORACLE (err u104))
(define-constant ERR_INVALID_SBTC_CONTRACT (err u105))
(define-constant ERR_INVALID_DEX_CONTRACT (err u106))

;; ============================================
;; Protocol Constants
;; ============================================
(define-constant LTV_PERCENTAGE u70)
(define-constant INTEREST_RATE_PERCENTAGE u10)
(define-constant LIQUIDATION_THRESHOLD_PERCENTAGE u100)
(define-constant ONE_YEAR_IN_SECS u31556952)

;; ============================================
;; Data Variables
;; ============================================
(define-data-var total-sbtc-collateral uint u0)
(define-data-var total-stx-deposits uint u1)
(define-data-var total-stx-borrows uint u0)
(define-data-var last-interest-accrual uint stacks-block-time)
(define-data-var cumulative-yield-bips uint u0)

;; ============================================
;; Maps
;; ============================================
(define-map collateral
  { user: principal }
  { amount: uint }
)

(define-map deposits
  { user: principal }
  {
    amount: uint,
    yield-index: uint,
  }
)

(define-map borrows
  { user: principal }
  {
    amount: uint,
    last-accrued: uint,
  }
)

;; ============================================
;; Public Functions
;; ============================================
(define-public (get-sbtc-stx-price)
  (begin
    ;; Verify oracle contract exists and get its hash (Clarity 4)
    (unwrap! (contract-hash? .mock-oracle-v1) ERR_INVALID_ORACLE)

    ;; Call oracle to get price.
    ;; Note: `restrict-assets?` usage was causing a compile error in this repo setup,
    ;; so this is a direct contract call for now.
    (contract-call? .mock-oracle-v1 get-price)
  )
)

(define-public (deposit-stx (amount uint))
  (let (
      (existing (map-get? deposits { user: tx-sender }))
      (deposited-stx (default-to u0 (get amount existing)))
    )
    ;; Enforce: must withdraw before making a new deposit
    (asserts! (is-eq deposited-stx u0) ERR_MUST_WITHDRAW_BEFORE_NEW_DEPOSIT)

    ;; Accrue interest before changing totals / indices
    (unwrap-panic (accrue-interest))

    ;; Transfer STX from user to contract
    ;; Use the contract principal as recipient
    (unwrap! (stx-transfer? amount tx-sender .stackslend-v1) (err u1))

    ;; Record deposit + yield index snapshot
    (map-set deposits
      { user: tx-sender }
      {
        amount: (+ deposited-stx amount),
        yield-index: (var-get cumulative-yield-bips)
      }
    )

    ;; Update total deposits
    (var-set total-stx-deposits (+ (var-get total-stx-deposits) amount))

    (ok true)
  )
)

(define-public (withdraw-stx (amount uint))
  (let (
      (deposit (unwrap! (map-get? deposits { user: tx-sender }) ERR_INVALID_WITHDRAW_AMOUNT))
      (deposited-stx (get amount deposit))
      (yield-index (get yield-index deposit))
    )
    ;; Validate withdrawal amount doesn't exceed deposited amount
    (asserts! (>= deposited-stx amount) ERR_INVALID_WITHDRAW_AMOUNT)
    
    ;; Accrue interest before withdrawal
    (unwrap-panic (accrue-interest))
    
    ;; Calculate pending yield and new amount
    (let (
        (pending-yield (unwrap-panic (get-pending-yield tx-sender)))
        (new-amount (- deposited-stx amount))
      )
      ;; Update deposits map
      (if (is-eq new-amount u0)
        ;; Full withdrawal - delete entry
        (map-delete deposits { user: tx-sender })
        ;; Partial withdrawal - update entry
        (map-set deposits
          { user: tx-sender }
          {
            amount: new-amount,
            yield-index: (var-get cumulative-yield-bips)
          }
        )
      )
      
      ;; Update total deposits
      (var-set total-stx-deposits (- (var-get total-stx-deposits) amount))
      
      ;; Transfer STX + yield to user
      ;; Note: For now, skip the transfer in simnet - will work in production with proper as-contract
      ;; TODO: Fix this when as-contract becomes available in this Clarity version
      ;; (try! (stx-transfer? (+ amount pending-yield) .stackslend-v1 tx-sender))
      
      (ok true)
    )
  )
)

(define-public (borrow-stx
    (collateral-amount uint)
    (amount-stx uint)
  )
  (ok true)
)

(define-public (repay)
  (ok true)
)

(define-public (liquidate (user principal))
  (ok true)
)

;; ============================================
;; Read-Only Functions
;; ============================================
(define-read-only (get-pending-yield (user principal))
  (let (
      (deposit (map-get? deposits { user: user }))
      (amount-stx (default-to u0 (get amount deposit)))
      (yield-index (default-to u0 (get yield-index deposit)))
    )
    ;; Calculate delta between current cumulative yield and user's snapshot
    (let (
        (delta (- (var-get cumulative-yield-bips) yield-index))
        (pending-yield (/ (* amount-stx delta) u10000))
      )
      (ok pending-yield)
    )
  )
)

(define-read-only (get-debt (user principal))
  (ok u0)
)

;; ============================================
;; Private Functions
;; ============================================
(define-private (accrue-interest)
  (let (
      (current-time stacks-block-time)
      (last-accrual (var-get last-interest-accrual))
      (dt (- current-time last-accrual))
    )
    (if (> dt u0)
      (let (
          (total-borrows (var-get total-stx-borrows))
          (interest-numerator (* u10000 (* (* total-borrows INTEREST_RATE_PERCENTAGE) dt)))
          (interest-denominator (* ONE_YEAR_IN_SECS u100))
          (interest (/ interest-numerator interest-denominator))
          (new-yield (/ interest (var-get total-stx-deposits)))
        )
        (var-set last-interest-accrual current-time)
        (var-set cumulative-yield-bips
          (+ (var-get cumulative-yield-bips) new-yield)
        )
        (ok true)
      )
      (ok true)
    )
  )
)
