---
title: "Trait stake-pool-alpha"
draft: true
---
```
;; Stake pool contract
(define-map stakes principal uint)
(define-data-var total-staked uint u0)
(define-data-var reward-rate uint u1)

(define-read-only (get-stake (user principal))
  (default-to u0 (map-get? stakes user))
)

(define-read-only (get-total-staked)
  (var-get total-staked)
)

(define-public (stake (amount uint))
  (begin
    (asserts! (> amount u0) (err u1))
    (let ((current (get-stake tx-sender)))
      (begin
        (map-set stakes tx-sender (+ current amount))
        (ok (var-set total-staked (+ (var-get total-staked) amount)))
      )
    )
  )
)

(define-public (unstake (amount uint))
  (let ((current (get-stake tx-sender)))
    (begin
      (asserts! (>= current amount) (err u2))
      (map-set stakes tx-sender (- current amount))
      (ok (var-set total-staked (- (var-get total-staked) amount)))
    )
  )
)

```
