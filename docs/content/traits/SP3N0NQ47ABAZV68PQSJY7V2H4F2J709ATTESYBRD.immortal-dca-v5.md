---
title: "Trait immortal-dca-v5"
draft: true
---
```
;; IMMORTAL DCA
;; The simplest unstoppable economic entity.
;; No owner. No admin. No governance. No kill switch.

;; ============================================
;; CONSTANTS
;; ============================================

(define-constant HEARTBEAT_INTERVAL u144)
(define-constant MIN_BALANCE u100000)
(define-constant TRIGGER_REWARD_BPS u100)
(define-constant MAX_REWARD u100000)

(define-constant ERR_TOO_SOON (err u1001))
(define-constant ERR_NO_FUNDS (err u1002))

;; ============================================
;; STATE
;; ============================================

(define-data-var last-heartbeat uint u0)
(define-data-var total-heartbeats uint u0)
(define-data-var total-rewards-paid uint u0)
(define-data-var balance uint u0)

;; ============================================
;; HELPERS
;; ============================================

(define-private (min-uint (a uint) (b uint))
  (if (<= a b) a b))

;; ============================================
;; READ-ONLY
;; ============================================

(define-read-only (get-balance)
  (var-get balance))

(define-read-only (get-blocks-until-next)
  (let (
    (last (var-get last-heartbeat))
    (now block-height)
    (next (+ last HEARTBEAT_INTERVAL))
  )
    (if (>= now next) u0 (- next now))))

(define-read-only (can-trigger)
  (and
    (is-eq (get-blocks-until-next) u0)
    (>= (get-balance) MIN_BALANCE)))

(define-read-only (get-stats)
  {
    balance: (get-balance),
    last-heartbeat: (var-get last-heartbeat),
    blocks-until-next: (get-blocks-until-next),
    total-heartbeats: (var-get total-heartbeats),
    total-rewards-paid: (var-get total-rewards-paid),
    can-trigger: (can-trigger)
  })

;; ============================================
;; PUBLIC
;; ============================================

;; Anyone can deposit STX
(define-public (deposit (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set balance (+ (var-get balance) amount))
    (ok amount)))

;; THE HEARTBEAT
(define-public (trigger)
  (let (
    (now block-height)
    (current-balance (var-get balance))
    (caller tx-sender)
  )
    (asserts! (>= now (+ (var-get last-heartbeat) HEARTBEAT_INTERVAL)) ERR_TOO_SOON)
    (asserts! (>= current-balance MIN_BALANCE) ERR_NO_FUNDS)

    (let (
      (raw-reward (/ (* current-balance TRIGGER_REWARD_BPS) u10000))
      (reward (min-uint raw-reward MAX_REWARD))
    )
      (try! (as-contract (stx-transfer? reward tx-sender caller)))

      (var-set balance (- current-balance reward))
      (var-set last-heartbeat now)
      (var-set total-heartbeats (+ (var-get total-heartbeats) u1))
      (var-set total-rewards-paid (+ (var-get total-rewards-paid) reward))

      (ok {
        heartbeat: (var-get total-heartbeats),
        reward: reward,
        triggered-by: caller,
        block: now
      })
    )))

```
