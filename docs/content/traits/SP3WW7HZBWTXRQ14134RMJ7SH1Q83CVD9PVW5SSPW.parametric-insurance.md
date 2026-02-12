---
title: "Trait parametric-insurance"
draft: true
---
```
;; Parametric Insurance Contract
;; Automatic payouts based on predefined parameters

(define-constant contract-owner tx-sender)
(define-data-var next-policy-id uint u1)

(define-map policies
  uint
  {
    holder: principal,
    coverage-amount: uint,
    premium: uint,
    trigger-condition: (string-ascii 64),
    trigger-value: uint,
    active: bool,
    expiry: uint
  }
)

(define-map claims uint { policy-id: uint, triggered: bool, payout: uint, timestamp: uint })
(define-data-var next-claim-id uint u1)

(define-read-only (get-policy (policy-id uint))
  (map-get? policies policy-id)
)

(define-public (create-policy (coverage uint) (premium uint) (condition (string-ascii 64)) (trigger uint) (duration uint))
  (let ((policy-id (var-get next-policy-id)))
    (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
    (map-set policies policy-id {
      holder: tx-sender,
      coverage-amount: coverage,
      premium: premium,
      trigger-condition: condition,
      trigger-value: trigger,
      active: true,
      expiry: (+ block-height duration)
    })
    (var-set next-policy-id (+ policy-id u1))
    (ok policy-id)
  )
)

(define-public (trigger-payout (policy-id uint) (observed-value uint))
  (let ((policy (unwrap! (map-get? policies policy-id) (err u100))))
    (asserts! (is-eq tx-sender contract-owner) (err u101))
    (asserts! (get active policy) (err u102))
    (asserts! (< block-height (get expiry policy)) (err u103))
    
    (if (>= observed-value (get trigger-value policy))
      (let ((claim-id (var-get next-claim-id)))
        (try! (as-contract (stx-transfer? (get coverage-amount policy) tx-sender (get holder policy))))
        (map-set claims claim-id {
          policy-id: policy-id,
          triggered: true,
          payout: (get coverage-amount policy),
          timestamp: block-height
        })
        (map-set policies policy-id (merge policy { active: false }))
        (var-set next-claim-id (+ claim-id u1))
        (ok (get coverage-amount policy))
      )
      (ok u0)
    )
  )
)

(define-public (cancel-policy (policy-id uint))
  (let ((policy (unwrap! (map-get? policies policy-id) (err u100))))
    (asserts! (is-eq tx-sender (get holder policy)) (err u101))
    (asserts! (get active policy) (err u102))
    (map-set policies policy-id (merge policy { active: false }))
    (ok true)
  )
)
```
