---
title: "Trait time-locked-vesting"
draft: true
---
```
;; Time-Locked Vesting - Clarity 4
;; Token vesting with cliff and linear unlock

(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u1000))
(define-constant err-not-found (err u1001))
(define-constant err-too-early (err u1002))
(define-constant err-already-claimed (err u1003))

(define-data-var vesting-nonce uint u0)

(define-map vesting-schedules
    uint
    {
        beneficiary: principal,
        total-amount: uint,
        start-height: uint,
        cliff-height: uint,
        end-height: uint,
        claimed-amount: uint,
        revoked: bool
    }
)

(define-read-only (get-vesting (schedule-id uint))
    (map-get? vesting-schedules schedule-id)
)

(define-read-only (calculate-vested (schedule-id uint))
    (match (get-vesting schedule-id)
        schedule
        (if (< stacks-block-height (get cliff-height schedule))
            u0
            (if (>= stacks-block-height (get end-height schedule))
                (get total-amount schedule)
                (let (
                    (elapsed (- stacks-block-height (get start-height schedule)))
                    (duration (- (get end-height schedule) (get start-height schedule)))
                    (vested (/ (* (get total-amount schedule) elapsed) duration))
                )
                    vested
                )
            )
        )
        u0
    )
)

(define-public (create-vesting
    (beneficiary principal)
    (amount uint)
    (cliff-blocks uint)
    (duration-blocks uint)
)
    (let (
        (schedule-id (var-get vesting-nonce))
        (start stacks-block-height)
        (cliff (+ start cliff-blocks))
        (end (+ start duration-blocks))
    )
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set vesting-schedules schedule-id {
            beneficiary: beneficiary,
            total-amount: amount,
            start-height: start,
            cliff-height: cliff,
            end-height: end,
            claimed-amount: u0,
            revoked: false
        })
        (var-set vesting-nonce (+ schedule-id u1))
        (ok schedule-id)
    )
)

(define-public (claim-vested (schedule-id uint))
    (let (
        (schedule (unwrap! (get-vesting schedule-id) err-not-found))
        (vested (calculate-vested schedule-id))
        (claimable (- vested (get claimed-amount schedule)))
    )
        (asserts! (is-eq tx-sender (get beneficiary schedule)) err-not-authorized)
        (asserts! (>= stacks-block-height (get cliff-height schedule)) err-too-early)
        (asserts! (> claimable u0) err-already-claimed)
        
        (map-set vesting-schedules schedule-id 
            (merge schedule {claimed-amount: vested})
        )
        (try! (as-contract (stx-transfer? claimable tx-sender (get beneficiary schedule))))
        (ok claimable)
    )
)

(define-public (revoke-vesting (schedule-id uint))
    (let (
        (schedule (unwrap! (get-vesting schedule-id) err-not-found))
        (vested (calculate-vested schedule-id))
        (unclaimed (- vested (get claimed-amount schedule)))
        (unvested (- (get total-amount schedule) vested))
    )
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        
        ;; Transfer unclaimed vested to beneficiary
        (if (> unclaimed u0)
            (try! (as-contract (stx-transfer? unclaimed tx-sender (get beneficiary schedule))))
            true
        )
        
        ;; Return unvested to owner
        (if (> unvested u0)
            (try! (as-contract (stx-transfer? unvested tx-sender contract-owner)))
            true
        )
        
        (ok (map-set vesting-schedules schedule-id 
            (merge schedule {revoked: true, claimed-amount: vested})
        ))
    )
)

```
