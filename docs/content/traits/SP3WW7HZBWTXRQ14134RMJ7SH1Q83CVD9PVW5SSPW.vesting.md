---
title: "Trait vesting"
draft: true
---
```
;; Vesting Contract

(define-constant contract-owner tx-sender)
(define-constant err-not-found (err u100))

(define-map vesting-schedules
  principal
  {
    total-amount: uint,
    released: uint,
    start-block: uint,
    duration: uint
  }
)

(define-read-only (get-vesting-schedule (beneficiary principal))
  (map-get? vesting-schedules beneficiary)
)

(define-public (create-vesting-schedule (beneficiary principal) (amount uint) (duration uint))
  (begin
    (map-set vesting-schedules beneficiary {
      total-amount: amount,
      released: u0,
      start-block: block-height,
      duration: duration
    })
    (ok true)
  )
)

(define-public (release-vested)
  (let ((schedule (unwrap! (map-get? vesting-schedules tx-sender) err-not-found)))
    (let ((vested-amount (/ (* (get total-amount schedule) (- block-height (get start-block schedule))) (get duration schedule))))
      (ok vested-amount)
    )
  )
)

```
