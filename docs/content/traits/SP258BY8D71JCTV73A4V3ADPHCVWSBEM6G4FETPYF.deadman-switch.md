---
title: "Trait deadman-switch"
draft: true
---
```
;; deadman-switch.clar
;; Funds release system based on owner inactivity

;; Constants
(define-constant CONTRACT-ADDRESS .deadman-switch)
(define-constant CONTRACT-OWNER tx-sender)
(define-constant CHECK-IN-INTERVAL u86400) ;; 1 day default
(define-constant ERR-NOT-OWNER (err u100))
(define-constant ERR-ALREADY-TRIGGERED (err u101))
(define-constant ERR-NOT-YET-TRIGGERED (err u102))
(define-constant ERR-INVALID-PERCENTAGE (err u103))
(define-constant ERR-ALREADY-BENEFICIARY (err u104))
(define-constant ERR-NOT-A-BENEFICIARY (err u105))

;; Data Variables
(define-data-var last-check-in uint stacks-block-time)
(define-data-var is-triggered bool false)
(define-data-var total-percentage uint u0) ;; Basis points (10000 = 100%)

;; Maps
(define-map beneficiaries principal { percentage: uint, active: bool })

;; Public Functions
(define-public (check-in (message (string-ascii 64)))
  (begin
    (asserts! (not (var-get is-triggered)) ERR-ALREADY-TRIGGERED)
    
    (var-set last-check-in stacks-block-time)
    (print { event: "checked-in", owner: tx-sender, time: stacks-block-time, msg: message })
    (ok true)
  )
)

(define-public (add-beneficiary (addr principal) (percentage uint))
  (begin
    (asserts! (not (var-get is-triggered)) ERR-ALREADY-TRIGGERED)
    (asserts! (is-none (map-get? beneficiaries addr)) ERR-ALREADY-BENEFICIARY)
    (asserts! (<= (+ (var-get total-percentage) percentage) u10000) ERR-INVALID-PERCENTAGE)
    
    (map-set beneficiaries addr { percentage: percentage, active: true })
    (var-set total-percentage (+ (var-get total-percentage) percentage))
    (ok true)
  )
)

(define-public (trigger)
  (begin
    (asserts! (not (var-get is-triggered)) ERR-ALREADY-TRIGGERED)
    (asserts! (>= stacks-block-time (+ (var-get last-check-in) CHECK-IN-INTERVAL)) ERR-NOT-YET-TRIGGERED)
    
    (var-set is-triggered true)
    (print { event: "triggered", time: stacks-block-time })
    (ok true)
  )
)

;; release-funds would normally distribute STX balance
;; but Clarity doesn't support easy iteration over map keys to release to all
;; A better design for Clarity would be for each beneficiary to claim their share
(define-public (claim-beneficiary-share)
  (let (
    (beneficiary (unwrap! (map-get? beneficiaries tx-sender) ERR-NOT-A-BENEFICIARY))
    (balance (stx-get-balance CONTRACT-ADDRESS))
  )
    (begin
      (asserts! (var-get is-triggered) ERR-NOT-YET-TRIGGERED)
      (asserts! (get active beneficiary) ERR-NOT-A-BENEFICIARY)
      
      (let ((amount (/ (* balance (get percentage beneficiary)) u10000)))
        (begin
          (map-set beneficiaries tx-sender (merge beneficiary { active: false }))
          (try! (stx-transfer? amount CONTRACT-ADDRESS tx-sender))
          (ok amount)
        )
      )
    )
  )
)

;; Read-only
(define-read-only (get-stats)
  {
    owner: CONTRACT-OWNER,
    last-check-in: (var-get last-check-in),
    interval: CHECK-IN-INTERVAL,
    triggered: (var-get is-triggered),
    total-pct: (var-get total-percentage)
  }
)

```
