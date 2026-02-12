---
title: "Trait crowdfunding"
draft: true
---
```
;; Community Crowdfund Contract

;; Constants
(define-constant GOAL u1000000) ;; 1 STX Goal
(define-constant OWNER tx-sender)

;; State Variables
(define-data-var total-pledged uint u0)
(define-map pledges principal uint)

;; Public: Pledge STX to the project
(define-public (pledge (amount uint))
  (begin
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    ;; Update user's pledge amount in the map
    (map-set pledges tx-sender (+ (default-to u0 (map-get? pledges tx-sender)) amount))
    ;; Update total
    (var-set total-pledged (+ (var-get total-pledged) amount))
    (ok "Pledge successful!")
  )
)

;; Public: Refund if the goal hasn't been met (Self-Service)
(define-public (refund)
  (let (
    (user-pledge (default-to u0 (map-get? pledges tx-sender)))
  )
    (asserts! (< (var-get total-pledged) GOAL) (err u405))
    (asserts! (> user-pledge u0) (err u404))
    
    ;; Send money back
    (try! (as-contract (stx-transfer? user-pledge (as-contract tx-sender) tx-sender)))
    
    ;; Reset user's pledge
    (map-delete pledges tx-sender)
    (ok "Refunded!")
  )
)

;; Read-only: Check status
(define-read-only (get-status)
  {
    current-total: (var-get total-pledged),
    target-goal: GOAL,
    is-goal-met: (>= (var-get total-pledged) GOAL)
  }
)

```
