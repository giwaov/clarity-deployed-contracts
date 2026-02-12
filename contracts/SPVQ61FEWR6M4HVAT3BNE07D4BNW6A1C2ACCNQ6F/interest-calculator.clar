;; Interest Calculator Contract
;; Calculates and manages dynamic interest rates based on pool utilization

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_INVALID_RATE (err u301))
(define-constant ERR_INVALID_UTILIZATION (err u302))

;; Interest rate model parameters
;; Base rate: 2% APY when utilization is 0%
(define-constant BASE_RATE u2000000) ;; 2% with 6 decimal precision (2 * 1e6 / 100)

;; Rate at optimal utilization (80%): 10% APY
(define-constant OPTIMAL_RATE u10000000) ;; 10% with 6 decimal precision

;; Maximum rate at 100% utilization: 50% APY
(define-constant MAX_RATE u50000000) ;; 50% with 6 decimal precision

;; Optimal utilization: 80%
(define-constant OPTIMAL_UTILIZATION u80)

;; Precision constants
(define-constant RATE_PRECISION u1000000) ;; 1e6 for 6 decimal places
(define-constant UTILIZATION_PRECISION u100) ;; Percentage

;; Blocks per year (approximately, assuming 10 minute blocks)
(define-constant BLOCKS_PER_YEAR u52560)

;; Data Variables
(define-data-var current-utilization-rate uint u0)
(define-data-var current-borrow-rate uint BASE_RATE)
(define-data-var current-supply-rate uint u0)
(define-data-var last-rate-update uint u0)
(define-data-var total-interest-accrued uint u0)

;; Custom rate parameters (can be updated by admin)
(define-data-var base-rate-param uint BASE_RATE)
(define-data-var optimal-rate-param uint OPTIMAL_RATE)
(define-data-var max-rate-param uint MAX_RATE)
(define-data-var optimal-utilization-param uint OPTIMAL_UTILIZATION)

;; Data Maps
(define-map rate-history
  uint ;; block height
  {
    utilization: uint,
    borrow-rate: uint,
    supply-rate: uint
  }
)

(define-map interest-accrual-log
  uint ;; log-id
  {
    block-height: uint,
    interest-amount: uint,
    total-borrowed: uint,
    utilization: uint
  }
)

(define-data-var interest-log-count uint u0)

;; Read-only functions

(define-read-only (get-current-rate)
  (var-get current-borrow-rate)
)

(define-read-only (get-supply-rate)
  (var-get current-supply-rate)
)

(define-read-only (get-utilization-rate)
  (var-get current-utilization-rate)
)

(define-read-only (get-rate-parameters)
  {
    base-rate: (var-get base-rate-param),
    optimal-rate: (var-get optimal-rate-param),
    max-rate: (var-get max-rate-param),
    optimal-utilization: (var-get optimal-utilization-param)
  }
)

(define-read-only (calculate-borrow-rate (utilization uint))
  (if (<= utilization (var-get optimal-utilization-param))
    ;; Below optimal utilization: linear interpolation from base to optimal rate
    ;; rate = base_rate + (optimal_rate - base_rate) * (utilization / optimal_utilization)
    (let
      (
        (base (var-get base-rate-param))
        (optimal (var-get optimal-rate-param))
        (optimal-util (var-get optimal-utilization-param))
        (rate-slope (- optimal base))
      )
      (+ base (/ (* rate-slope utilization) optimal-util))
    )
    ;; Above optimal utilization: linear interpolation from optimal to max rate
    ;; rate = optimal_rate + (max_rate - optimal_rate) * ((utilization - optimal) / (100 - optimal))
    (let
      (
        (optimal (var-get optimal-rate-param))
        (max-rate (var-get max-rate-param))
        (optimal-util (var-get optimal-utilization-param))
        (excess-utilization (- utilization optimal-util))
        (rate-slope (- max-rate optimal))
        (utilization-range (- UTILIZATION_PRECISION optimal-util))
      )
      (+ optimal (/ (* rate-slope excess-utilization) utilization-range))
    )
  )
)

(define-read-only (calculate-supply-rate (utilization uint) (borrow-rate uint))
  ;; Supply rate = borrow rate * utilization * (1 - reserve factor)
  ;; For simplicity, we assume 0% reserve factor
  ;; supply_rate = borrow_rate * utilization / 100
  (/ (* borrow-rate utilization) UTILIZATION_PRECISION)
)

(define-read-only (calculate-interest (principal-amount uint) (rate uint) (blocks uint))
  ;; Interest = principal * rate * blocks / (BLOCKS_PER_YEAR * RATE_PRECISION * 100)
  ;; The rate is already in percentage * 1e6, so we divide by 100 * 1e6
  (/ (* (* principal-amount rate) blocks) (* BLOCKS_PER_YEAR (* RATE_PRECISION UTILIZATION_PRECISION)))
)

(define-read-only (get-rate-at-block (block uint))
  (map-get? rate-history block)
)

(define-read-only (get-total-interest-accrued)
  (var-get total-interest-accrued)
)

(define-read-only (estimate-apy (rate uint))
  ;; Convert rate to APY percentage
  ;; APY = rate / 1e6 (since rate is already in percentage * 1e6)
  (/ rate u10000) ;; Returns APY in basis points (1/100th of a percent)
)

;; Public functions

(define-public (update-rates (utilization uint))
  (let
    (
      (new-borrow-rate (calculate-borrow-rate utilization))
      (new-supply-rate (calculate-supply-rate utilization new-borrow-rate))
    )
    ;; Validate utilization is within bounds
    (asserts! (<= utilization UTILIZATION_PRECISION) ERR_INVALID_UTILIZATION)
    
    ;; Update rates
    (var-set current-utilization-rate utilization)
    (var-set current-borrow-rate new-borrow-rate)
    (var-set current-supply-rate new-supply-rate)
    (var-set last-rate-update block-height)
    
    ;; Store rate history
    (map-set rate-history block-height
      {
        utilization: utilization,
        borrow-rate: new-borrow-rate,
        supply-rate: new-supply-rate
      }
    )
    
    (ok {
      utilization: utilization,
      borrow-rate: new-borrow-rate,
      supply-rate: new-supply-rate
    })
  )
)

(define-public (accrue-interest (principal-amount uint))
  (let
    (
      (blocks-elapsed (- block-height (var-get last-rate-update)))
      (current-rate (var-get current-borrow-rate))
      (interest (calculate-interest principal-amount current-rate blocks-elapsed))
    )
    ;; Log interest accrual
    (let
      (
        (log-id (+ (var-get interest-log-count) u1))
      )
      (map-set interest-accrual-log log-id
        {
          block-height: block-height,
          interest-amount: interest,
          total-borrowed: principal-amount,
          utilization: (var-get current-utilization-rate)
        }
      )
      (var-set interest-log-count log-id)
      (var-set total-interest-accrued (+ (var-get total-interest-accrued) interest))
    )
    
    (ok interest)
  )
)

;; Admin functions

(define-public (update-rate-parameters 
  (new-base-rate uint)
  (new-optimal-rate uint)
  (new-max-rate uint)
  (new-optimal-utilization uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    ;; Validate parameters
    (asserts! (<= new-base-rate new-optimal-rate) ERR_INVALID_RATE)
    (asserts! (<= new-optimal-rate new-max-rate) ERR_INVALID_RATE)
    (asserts! (<= new-optimal-utilization UTILIZATION_PRECISION) ERR_INVALID_UTILIZATION)
    
    ;; Update parameters
    (var-set base-rate-param new-base-rate)
    (var-set optimal-rate-param new-optimal-rate)
    (var-set max-rate-param new-max-rate)
    (var-set optimal-utilization-param new-optimal-utilization)
    
    ;; Return success - rates will be updated on next pool interaction
    (ok true)
  )
)

(define-public (get-interest-log (log-id uint))
  (ok (map-get? interest-accrual-log log-id))
)

;; Utility functions

(define-read-only (get-apr-from-apy (apy uint))
  ;; Simple conversion for display purposes
  ;; In reality, APR = (1 + APY)^(1/n) - 1, but we simplify here
  apy
)

(define-read-only (calculate-compound-interest 
  (principal uint) 
  (rate uint) 
  (time-periods uint))
  ;; Compound interest = principal * (1 + rate/n)^(n*t)
  ;; Simplified for blockchain: principal * (1 + rate * time / precision)
  (let
    (
      (rate-per-period (/ rate BLOCKS_PER_YEAR))
      (interest-multiplier (+ RATE_PRECISION (/ (* rate-per-period time-periods) UTILIZATION_PRECISION)))
      (final-amount (/ (* principal interest-multiplier) RATE_PRECISION))
    )
    final-amount
  )
)
