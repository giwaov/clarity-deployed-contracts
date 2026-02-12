---
title: "Trait staking-pool"
draft: true
---
```
;; Staking Pool Contract

(define-constant contract-owner tx-sender)
(define-constant err-insufficient-balance (err u100))
(define-constant err-invalid-amount (err u101))

(define-map stakes principal uint)
(define-data-var total-staked uint u0)

(define-read-only (get-staked-balance (user principal))
  (default-to u0 (map-get? stakes user))
)

(define-read-only (get-total-staked)
  (var-get total-staked)
)

(define-public (stake (amount uint))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set stakes tx-sender (+ (get-staked-balance tx-sender) amount))
    (var-set total-staked (+ (var-get total-staked) amount))
    (ok amount)
  )
)

(define-public (unstake (amount uint))
  (let ((balance (get-staked-balance tx-sender)))
    (asserts! (>= balance amount) err-insufficient-balance)
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (map-set stakes tx-sender (- balance amount))
    (var-set total-staked (- (var-get total-staked) amount))
    (ok amount)
  )
)

```
