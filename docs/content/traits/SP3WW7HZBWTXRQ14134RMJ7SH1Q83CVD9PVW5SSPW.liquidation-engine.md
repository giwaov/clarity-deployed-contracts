---
title: "Trait liquidation-engine"
draft: true
---
```
;; Liquidation Engine Contract
;; Handles liquidation of undercollateralized positions

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-liquidatable (err u101))
(define-constant err-invalid-amount (err u102))
(define-constant err-already-liquidated (err u103))

;; Data Variables
(define-data-var liquidation-threshold uint u120) ;; 120% threshold
(define-data-var liquidation-bonus uint u10) ;; 10% bonus for liquidators
(define-data-var max-liquidation-close uint u50) ;; Max 50% of debt can be liquidated

;; Data Maps
(define-map liquidation-history 
  uint 
  {
    liquidator: principal,
    borrower: principal,
    collateral-seized: uint,
    debt-repaid: uint,
    timestamp: uint
  }
)

(define-data-var next-liquidation-id uint u1)

;; Read-only functions
(define-read-only (get-liquidation-threshold)
  (var-get liquidation-threshold)
)

(define-read-only (is-liquidatable (collateral uint) (debt uint))
  (let (
    (collateral-value collateral)
    (debt-value debt)
    (health-factor (if (is-eq debt-value u0)
                     u1000
                     (/ (* collateral-value u100) debt-value)))
  )
    (< health-factor (var-get liquidation-threshold))
  )
)

(define-read-only (calculate-liquidation-amount (debt uint))
  (/ (* debt (var-get max-liquidation-close)) u100)
)

(define-read-only (calculate-collateral-to-seize (debt-to-cover uint) (collateral-price uint))
  (let (
    (base-collateral (/ debt-to-cover collateral-price))
    (bonus-amount (/ (* base-collateral (var-get liquidation-bonus)) u100))
  )
    (+ base-collateral bonus-amount)
  )
)

(define-read-only (get-liquidation-details (liquidation-id uint))
  (map-get? liquidation-history liquidation-id)
)

;; Public functions
(define-public (liquidate (borrower principal) (debt-to-cover uint))
  (let (
    (liquidation-id (var-get next-liquidation-id))
    ;; In production, these would come from oracle or lending pool
    (borrower-collateral u1000000)
    (borrower-debt u900000)
  )
    (asserts! (> debt-to-cover u0) err-invalid-amount)
    (asserts! (is-liquidatable borrower-collateral borrower-debt) err-not-liquidatable)
    
    (let (
      (max-liquidation (calculate-liquidation-amount borrower-debt))
      (actual-debt-to-cover (if (<= debt-to-cover max-liquidation)
                              debt-to-cover
                              max-liquidation))
      (collateral-to-seize (calculate-collateral-to-seize actual-debt-to-cover u1))
    )
      ;; Transfer debt payment from liquidator
      (try! (stx-transfer? actual-debt-to-cover tx-sender (as-contract tx-sender)))
      
      ;; Transfer collateral to liquidator
      (try! (as-contract (stx-transfer? collateral-to-seize tx-sender tx-sender)))
      
      ;; Record liquidation
      (map-set liquidation-history liquidation-id {
        liquidator: tx-sender,
        borrower: borrower,
        collateral-seized: collateral-to-seize,
        debt-repaid: actual-debt-to-cover,
        timestamp: block-height
      })
      
      (var-set next-liquidation-id (+ liquidation-id u1))
      
      (ok {
        liquidation-id: liquidation-id,
        collateral-seized: collateral-to-seize,
        debt-repaid: actual-debt-to-cover
      })
    )
  )
)

;; Admin functions
(define-public (update-liquidation-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set liquidation-threshold new-threshold)
    (ok true)
  )
)

(define-public (update-liquidation-bonus (new-bonus uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set liquidation-bonus new-bonus)
    (ok true)
  )
)

(define-public (update-max-liquidation-close (new-max uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-max u100) err-invalid-amount)
    (var-set max-liquidation-close new-max)
    (ok true)
  )
)

```
