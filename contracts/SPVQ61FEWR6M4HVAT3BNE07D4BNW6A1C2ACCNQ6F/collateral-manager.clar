;; Collateral Manager Contract
;; Handles collateral valuation, health factor checks, and liquidations

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_POSITION_HEALTHY (err u201))
(define-constant ERR_INVALID_LIQUIDATION (err u202))
(define-constant ERR_NO_POSITION (err u203))
(define-constant ERR_PRICE_NOT_AVAILABLE (err u204))

;; Liquidation bonus: 5% (represented as 105 out of 100)
(define-constant LIQUIDATION_BONUS u105)
(define-constant LIQUIDATION_BONUS_DENOMINATOR u100)

;; Minimum health factor for liquidation: 1.0 (represented as 100 out of 100)
(define-constant LIQUIDATION_THRESHOLD u100)
(define-constant HEALTH_FACTOR_DENOMINATOR u100)

;; Collateral ratio from lending-pool
(define-constant COLLATERAL_RATIO u75)
(define-constant COLLATERAL_RATIO_DENOMINATOR u100)

;; Data Variables
(define-data-var liquidation-count uint u0)
(define-data-var total-liquidated-collateral uint u0)
(define-data-var total-liquidated-debt uint u0)

;; Data Maps
(define-map liquidation-events
  uint ;; liquidation-id
  {
    liquidated-user: principal,
    liquidator: principal,
    collateral-seized: uint,
    debt-repaid: uint,
    liquidation-block: uint,
    health-factor-before: uint
  }
)

(define-map collateral-prices
  { asset: (string-ascii 10) }
  {
    price: uint,
    last-update: uint,
    decimals: uint
  }
)

(define-map user-liquidation-history
  principal
  { times-liquidated: uint, total-collateral-lost: uint }
)

;; Read-only functions

(define-read-only (get-collateral-price (asset (string-ascii 10)))
  (match (map-get? collateral-prices { asset: asset })
    price-data (ok price-data)
    ERR_PRICE_NOT_AVAILABLE
  )
)

(define-read-only (calculate-collateral-value (amount uint) (price uint))
  ;; For STX, we assume 1:1 for simplicity, but this can be extended
  ;; Value = amount * price / 1e6 (assuming 6 decimal precision)
  (/ (* amount price) u1000000)
)

(define-read-only (check-health-factor (user principal))
  (let
    (
      (position (contract-call? .lending-pool get-user-position user))
      (collateral (get collateral position))
      (current-debt (contract-call? .lending-pool calculate-current-debt user))
    )
    (if (is-eq current-debt u0)
      (ok u999999) ;; No debt = healthy
      (let
        (
          ;; Health factor = (collateral * COLLATERAL_RATIO / 100) / debt * 100
          (collateral-value (/ (* collateral COLLATERAL_RATIO) COLLATERAL_RATIO_DENOMINATOR))
          (health-factor (/ (* collateral-value HEALTH_FACTOR_DENOMINATOR) current-debt))
        )
        (ok health-factor)
      )
    )
  )
)

(define-read-only (is-liquidatable (user principal))
  (let
    (
      (health-factor (unwrap! (check-health-factor user) (err u999)))
    )
    (ok (<= health-factor LIQUIDATION_THRESHOLD))
  )
)

(define-read-only (calculate-liquidation-amount (user principal))
  (let
    (
      (position (contract-call? .lending-pool get-user-position user))
      (collateral (get collateral position))
      (current-debt (contract-call? .lending-pool calculate-current-debt user))
    )
    (if (is-eq current-debt u0)
      (ok { debt-to-repay: u0, collateral-to-seize: u0 })
      (let
        (
          ;; In a partial liquidation, we liquidate 50% of the debt
          (debt-to-repay (/ current-debt u2))
          ;; Collateral to seize = debt-to-repay * LIQUIDATION_BONUS / 100
          (collateral-to-seize (/ (* debt-to-repay LIQUIDATION_BONUS) LIQUIDATION_BONUS_DENOMINATOR))
        )
        (ok { debt-to-repay: debt-to-repay, collateral-to-seize: collateral-to-seize })
      )
    )
  )
)

(define-read-only (get-liquidation-event (liquidation-id uint))
  (map-get? liquidation-events liquidation-id)
)

(define-read-only (get-user-liquidation-history (user principal))
  (default-to
    { times-liquidated: u0, total-collateral-lost: u0 }
    (map-get? user-liquidation-history user)
  )
)

(define-read-only (get-liquidation-stats)
  {
    total-liquidations: (var-get liquidation-count),
    total-collateral-seized: (var-get total-liquidated-collateral),
    total-debt-repaid: (var-get total-liquidated-debt)
  }
)

;; Public functions

(define-public (liquidate-position (user principal) (debt-to-repay uint))
  (begin
    ;; Check if position is liquidatable
    (asserts! (unwrap! (is-liquidatable user) ERR_INVALID_LIQUIDATION) ERR_POSITION_HEALTHY)
    
    (let
      (
        (position (contract-call? .lending-pool get-user-position user))
        (collateral (get collateral position))
        (current-debt (contract-call? .lending-pool calculate-current-debt user))
        (health-factor-before (unwrap! (check-health-factor user) ERR_INVALID_LIQUIDATION))
        (max-liquidation (unwrap! (calculate-liquidation-amount user) ERR_INVALID_LIQUIDATION))
        (max-debt-to-repay (get debt-to-repay max-liquidation))
        (actual-debt-to-repay (if (<= debt-to-repay max-debt-to-repay) debt-to-repay max-debt-to-repay))
      )
      (asserts! (> current-debt u0) ERR_NO_POSITION)
      (asserts! (> actual-debt-to-repay u0) ERR_INVALID_LIQUIDATION)
      
      ;; Calculate collateral to seize with bonus
      (let
        (
          (collateral-to-seize (/ (* actual-debt-to-repay LIQUIDATION_BONUS) LIQUIDATION_BONUS_DENOMINATOR))
        )
        ;; Ensure we don't seize more collateral than available
        (asserts! (<= collateral-to-seize collateral) ERR_INVALID_LIQUIDATION)
        
        ;; Transfer debt repayment from liquidator to contract
        (try! (stx-transfer? actual-debt-to-repay tx-sender (as-contract tx-sender)))
        
        ;; Transfer seized collateral from contract to liquidator
        (try! (as-contract (stx-transfer? collateral-to-seize tx-sender tx-sender)))
        
        ;; Update the user's position in lending-pool
        ;; Note: In a production system, we'd need a callback mechanism
        ;; For now, we assume the lending pool has a liquidation function
        
        ;; Record liquidation event
        (let
          (
            (liquidation-id (+ (var-get liquidation-count) u1))
          )
          (map-set liquidation-events liquidation-id
            {
              liquidated-user: user,
              liquidator: tx-sender,
              collateral-seized: collateral-to-seize,
              debt-repaid: actual-debt-to-repay,
              liquidation-block: block-height,
              health-factor-before: health-factor-before
            }
          )
          
          ;; Update liquidation stats
          (var-set liquidation-count liquidation-id)
          (var-set total-liquidated-collateral (+ (var-get total-liquidated-collateral) collateral-to-seize))
          (var-set total-liquidated-debt (+ (var-get total-liquidated-debt) actual-debt-to-repay))
          
          ;; Update user liquidation history
          (let
            (
              (user-history (get-user-liquidation-history user))
            )
            (map-set user-liquidation-history user
              {
                times-liquidated: (+ (get times-liquidated user-history) u1),
                total-collateral-lost: (+ (get total-collateral-lost user-history) collateral-to-seize)
              }
            )
          )
          
          (ok {
            collateral-seized: collateral-to-seize,
            debt-repaid: actual-debt-to-repay,
            liquidation-id: liquidation-id
          })
        )
      )
    )
  )
)

(define-public (update-collateral-price (asset (string-ascii 10)) (price uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set collateral-prices { asset: asset }
      {
        price: price,
        last-update: block-height,
        decimals: u6
      }
    )
    (ok true)
  )
)

;; Private functions for integration (to be called by lending-pool)

(define-public (validate-collateral-ratio (collateral uint) (debt uint))
  (let
    (
      (max-debt (/ (* collateral COLLATERAL_RATIO) COLLATERAL_RATIO_DENOMINATOR))
    )
    (ok (<= debt max-debt))
  )
)

;; Initialize with default STX price (1 STX = $1 for testing)
(begin
  (map-set collateral-prices { asset: "STX" }
    {
      price: u1000000, ;; $1.00 with 6 decimals
      last-update: block-height,
      decimals: u6
    }
  )
)
