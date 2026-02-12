---
title: "Trait timelocks"
draft: true
---
```
;; timelock.clar
;; Funds locking system with release conditions

;; Constants
(define-constant CONTRACT-ADDRESS .timelock)
(define-constant ERR-LOCK-NOT-FOUND (err u100))
(define-constant ERR-NOT-CREATOR (err u101))
(define-constant ERR-NOT-BENEFICIARY (err u102))
(define-constant ERR-LOCK-NOT-READY (err u103))
(define-constant ERR-ALREADY-RELEASED (err u104))
(define-constant ERR-ZERO-AMOUNT (err u105))

;; Data Variables
(define-data-var lock-counter uint u0)

;; Maps
(define-map locks uint 
  {
    creator: principal,
    beneficiary: principal,
    amount: uint,
    unlock-time: uint,
    released: bool,
    cancelled: bool
  }
)

;; Public Functions
(define-public (create-lock (beneficiary principal) (unlock-time uint) (amount uint))
  (let ((lock-id (+ (var-get lock-counter) u1)))
    (begin
      (asserts! (> amount u0) ERR-ZERO-AMOUNT)
      (asserts! (not (is-eq beneficiary tx-sender)) (err u107))
      (asserts! (> unlock-time stacks-block-time) (err u106))
      
      (unwrap-panic (stx-transfer? amount tx-sender CONTRACT-ADDRESS))
      
      (map-set locks lock-id {
        creator: tx-sender,
        beneficiary: beneficiary,
        amount: amount,
        unlock-time: unlock-time,
        released: false,
        cancelled: false
      })
      
      (var-set lock-counter lock-id)
      (ok lock-id)
    )
  )
)

(define-public (release (lock-id uint))
  (let ((lock (unwrap! (map-get? locks lock-id) ERR-LOCK-NOT-FOUND)))
    (begin
      (asserts! (is-eq (get beneficiary lock) tx-sender) ERR-NOT-BENEFICIARY)
      (asserts! (not (get released lock)) ERR-ALREADY-RELEASED)
      (asserts! (not (get cancelled lock)) ERR-ALREADY-RELEASED)
      (asserts! (>= stacks-block-time (get unlock-time lock)) ERR-LOCK-NOT-READY)
      
      (map-set locks lock-id (merge lock { released: true }))
      (try! (stx-transfer? (get amount lock) CONTRACT-ADDRESS (get beneficiary lock)))
      (ok true)
    )
  )
)

(define-public (cancel (lock-id uint))
  (let ((lock (unwrap! (map-get? locks lock-id) ERR-LOCK-NOT-FOUND)))
    (begin
      (asserts! (is-eq (get creator lock) tx-sender) ERR-NOT-CREATOR)
      (asserts! (not (get released lock)) ERR-ALREADY-RELEASED)
      (asserts! (not (get cancelled lock)) ERR-ALREADY-RELEASED)
      
      (map-set locks lock-id (merge lock { cancelled: true }))
      (try! (stx-transfer? (get amount lock) CONTRACT-ADDRESS (get creator lock)))
      (ok true)
    )
  )
)

;; Read-only
(define-read-only (get-lock (lock-id uint))
  (map-get? locks lock-id)
)

;; CLARITY 4 FEATURE: to-ascii? for lock status
(define-read-only (get-lock-status-ascii (lock-id uint))
  (match (map-get? locks lock-id)
    lock (let (
      (amount-ascii (match (to-ascii? (get amount lock)) ok-val ok-val err "0"))
      (time-remaining (if (> (get unlock-time lock) stacks-block-time)
        (- (get unlock-time lock) stacks-block-time)
        u0))
      (time-ascii (match (to-ascii? time-remaining) ok-val ok-val err "0"))
      (status-str (if (get released lock) "RELEASED"
        (if (get cancelled lock) "CANCELLED"
        (if (> time-remaining u0) "LOCKED" "READY"))))
    )
      (ok {
        beneficiary: (get beneficiary lock),
        amount: amount-ascii,
        time-remaining: time-ascii,
        status: status-str
      })
    )
    (ok {
        beneficiary: tx-sender,
        amount: "0",
        time-remaining: "0",
        status: "NOT_FOUND"
    })
  )
)

```
