;; Interest Rate Model Contract
;; Calculates dynamic interest rates based on utilization

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-rate (err u101))

;; Data Variables
(define-data-var base-rate uint u2) ;; 2% base rate
(define-data-var multiplier uint u10) ;; 10% multiplier
(define-data-var jump-multiplier uint u50) ;; 50% jump multiplier
(define-data-var optimal-utilization uint u80) ;; 80% optimal utilization

;; Read-only functions
(define-read-only (get-base-rate)
  (var-get base-rate)
)

(define-read-only (calculate-utilization-rate (borrows uint) (deposits uint))
  (if (is-eq deposits u0)
    u0
    (/ (* borrows u100) deposits)
  )
)

(define-read-only (calculate-borrow-rate (utilization uint))
  (let (
    (optimal-util (var-get optimal-utilization))
  )
    (if (<= utilization optimal-util)
      ;; Below optimal: base-rate + (utilization * multiplier / optimal)
      (+ (var-get base-rate) 
         (/ (* utilization (var-get multiplier)) optimal-util))
      ;; Above optimal: base-rate + multiplier + excess-utilization * jump-multiplier
      (let (
        (excess-util (- utilization optimal-util))
      )
        (+ (var-get base-rate)
           (var-get multiplier)
           (/ (* excess-util (var-get jump-multiplier)) (- u100 optimal-util)))
      )
    )
  )
)

(define-read-only (calculate-supply-rate (borrow-rate uint) (utilization uint))
  ;; Supply rate = borrow rate * utilization * (1 - reserve factor)
  ;; Assuming 10% reserve factor
  (/ (* (* borrow-rate utilization) u90) u10000)
)

(define-read-only (get-current-rates (borrows uint) (deposits uint))
  (let (
    (utilization (calculate-utilization-rate borrows deposits))
    (borrow-rate (calculate-borrow-rate utilization))
    (supply-rate (calculate-supply-rate borrow-rate utilization))
  )
    {
      utilization: utilization,
      borrow-rate: borrow-rate,
      supply-rate: supply-rate
    }
  )
)

;; Admin functions
(define-public (update-base-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-rate u100) err-invalid-rate)
    (var-set base-rate new-rate)
    (ok true)
  )
)

(define-public (update-multiplier (new-multiplier uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-multiplier u100) err-invalid-rate)
    (var-set multiplier new-multiplier)
    (ok true)
  )
)

(define-public (update-jump-multiplier (new-jump uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set jump-multiplier new-jump)
    (ok true)
  )
)

(define-public (update-optimal-utilization (new-optimal uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (and (> new-optimal u0) (<= new-optimal u100)) err-invalid-rate)
    (var-set optimal-utilization new-optimal)
    (ok true)
  )
)
