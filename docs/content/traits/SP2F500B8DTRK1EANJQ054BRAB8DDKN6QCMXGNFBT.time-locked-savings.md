---
title: "Trait time-locked-savings"
draft: true
---
```
;; Time-Locked Savings
;; Lock funds for a period and earn bonus rewards

(define-constant contract-owner tx-sender)
(define-constant err-invalid-duration (err u700))
(define-constant err-deposit-not-found (err u701))
(define-constant err-still-locked (err u702))
(define-constant err-already-withdrawn (err u703))

(define-constant min-lock-period u144) ;; ~1 day
(define-constant max-lock-period u52560) ;; ~1 year

(define-map deposits
    { deposit-id: uint }
    {
        depositor: principal,
        amount: uint,
        lock-until: uint,
        bonus-rate: uint,
        withdrawn: bool
    }
)

(define-data-var deposit-counter uint u0)

;; Create time-locked deposit
(define-public (create-deposit (amount uint) (lock-duration uint))
    (let
        (
            (deposit-id (+ (var-get deposit-counter) u1))
            (bonus-rate (calculate-bonus-rate lock-duration))
        )
        (asserts! (>= lock-duration min-lock-period) err-invalid-duration)
        (asserts! (<= lock-duration max-lock-period) err-invalid-duration)
        
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        (map-set deposits
            { deposit-id: deposit-id }
            {
                depositor: tx-sender,
                amount: amount,
                lock-until: (+ stacks-block-height lock-duration),
                bonus-rate: bonus-rate,
                withdrawn: false
            }
        )
        (var-set deposit-counter deposit-id)
        (ok deposit-id)
    )
)

;; Withdraw after lock period
(define-public (withdraw (deposit-id uint))
    (let
        (
            (deposit (unwrap! (map-get? deposits { deposit-id: deposit-id }) err-deposit-not-found))
            (total-amount (+ (get amount deposit) (calculate-bonus (get amount deposit) (get bonus-rate deposit))))
        )
        (asserts! (is-eq tx-sender (get depositor deposit)) err-deposit-not-found)
        (asserts! (>= stacks-block-height (get lock-until deposit)) err-still-locked)
        (asserts! (not (get withdrawn deposit)) err-already-withdrawn)
        
        (try! (as-contract (stx-transfer? total-amount tx-sender (get depositor deposit))))
        
        (map-set deposits
            { deposit-id: deposit-id }
            (merge deposit { withdrawn: true })
        )
        (ok total-amount)
    )
)

;; Calculate bonus rate based on lock duration
(define-private (calculate-bonus-rate (duration uint))
    (if (>= duration u26280)
        u20 ;; 20% for 6 months+
        (if (>= duration u8760)
            u10 ;; 10% for 2 months+
            u5 ;; 5% for minimum lock
        )
    )
)

;; Calculate bonus amount
(define-private (calculate-bonus (amount uint) (rate uint))
    (/ (* amount rate) u100)
)

;; Read-only functions
(define-read-only (get-deposit (deposit-id uint))
    (map-get? deposits { deposit-id: deposit-id })
)

(define-read-only (get-withdrawal-amount (deposit-id uint))
    (match (map-get? deposits { deposit-id: deposit-id })
        deposit (ok (+ (get amount deposit) (calculate-bonus (get amount deposit) (get bonus-rate deposit))))
        err-deposit-not-found
    )
)

```
