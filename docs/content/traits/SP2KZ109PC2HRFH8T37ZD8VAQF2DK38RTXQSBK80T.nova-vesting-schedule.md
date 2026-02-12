---
title: "Trait nova-vesting-schedule"
draft: true
---
```

;; nova-vesting-schedule.clar
;; Linearly vests tokens for beneficiaries in Nova Protocol.
;; CLARITY VERSION: 2

(use-trait nova-trait-fungible .nova-trait-fungible.nova-trait-fungible)

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOTHING-TO-CLAIM (err u101))
(define-constant ERR-VESTING-NOT-FOUND (err u102))

(define-map vesting-schedules
    principal
    {
        total-amount: uint,
        start-block: uint,
        end-block: uint,
        claimed-amount: uint,
        token-principal: principal
    }
)

(define-public (create-vesting-schedule (beneficiary principal) (amount uint) (start-block uint) (end-block uint) (token-trait <nova-trait-fungible>))
    (let (
        (sender tx-sender)
    )
    (asserts! (> end-block start-block) (err u103))
    
    (try! (contract-call? token-trait transfer amount sender (as-contract tx-sender) none))

    (map-set vesting-schedules beneficiary {
        total-amount: amount,
        start-block: start-block,
        end-block: end-block,
        claimed-amount: u0,
        token-principal: (contract-of token-trait)
    })
    (ok true))
)

(define-public (claim-vested-tokens (token-trait <nova-trait-fungible>))
    (let (
        (sender tx-sender)
        (schedule (unwrap! (map-get? vesting-schedules sender) ERR-VESTING-NOT-FOUND))
        (current-block block-height)
        (vested-amount (calculate-vested-amount schedule current-block))
        (claimable (- vested-amount (get claimed-amount schedule)))
    )
    (asserts! (is-eq (contract-of token-trait) (get token-principal schedule)) ERR-NOT-AUTHORIZED)
    (asserts! (> claimable u0) ERR-NOTHING-TO-CLAIM)

    (try! (as-contract (contract-call? token-trait transfer claimable tx-sender sender none)))

    (map-set vesting-schedules sender (merge schedule { claimed-amount: vested-amount }))
    (ok claimable))
)

(define-read-only (calculate-vested-amount (schedule {total-amount: uint, start-block: uint, end-block: uint, claimed-amount: uint, token-principal: principal}) (current-block uint))
    (let (
        (total (get total-amount schedule))
        (start (get start-block schedule))
        (end (get end-block schedule))
    )
    (if (< current-block start)
        u0
        (if (>= current-block end)
            total
            (/ (* total (- current-block start)) (- end start))))
    )
)

(define-read-only (get-schedule (beneficiary principal))
    (map-get? vesting-schedules beneficiary)
)

```
