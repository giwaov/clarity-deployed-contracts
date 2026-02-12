---
title: "Trait vesting"
draft: true
---
```
;; vesting.clar
;; Linear vesting schedule

(define-map schedules principal { total: uint, released: uint, start: uint, duration: uint })

(define-public (create-vesting (beneficiary principal) (amount uint) (duration uint))
    (begin
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set schedules beneficiary { total: amount, released: u0, start: block-height, duration: duration })
        (ok true)
    )
)

(define-public (release)
    (let
        (
            (schedule (unwrap! (map-get? schedules tx-sender) (err u100)))
            (time-passed (- block-height (get start schedule)))
            (vested-amount (/ (* (get total schedule) time-passed) (get duration schedule)))
            (releasable (- vested-amount (get released schedule)))
        )
        (asserts! (> releasable u0) (err u101))
        (try! (as-contract (stx-transfer? releasable tx-sender tx-sender)))
        (map-set schedules tx-sender (merge schedule { released: (+ (get released schedule) releasable) }))
        (ok releasable)
    )
)

```
