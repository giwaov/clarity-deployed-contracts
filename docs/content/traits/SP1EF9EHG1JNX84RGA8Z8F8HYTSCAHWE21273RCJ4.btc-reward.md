---
title: "Trait btc-reward"
draft: true
---
```
(define-constant ERR_ALL_REWARDS_CLAIMED (err u450))
(define-constant ERR_SENDER_ALREADY_CLAIMED_REWARD (err u451))

(define-constant ERR_LOWER_THAN_16 (err u461))
(define-constant ERR_REGISTERED_TOO_SOON (err u642))

;; The start time of the reward compaign
;; Translates to Monday Dec 22 2025 14:00:00 UTC
;; Players must register their ATA factory (aka Miner) after this date
(define-constant START u1766412000)

;; Rewards values in sats
;; Will be delivered as sbtc
;; The first three players that fulfill the following conditions will be able to
;; claim the rewards in order, 1, 2, 3;
;; - registered after `START` Monday Dec 22 2025 14:00:00 UTC
;; - have ATA miner level 16
(define-constant REWARD_1 u112000) ;; ~$100
(define-constant REWARD_2 u67000) ;; ~$60
(define-constant REWARD_3 u45000) ;; ~$40

(define-data-var winner1 (optional principal) none)
(define-data-var winner2 (optional principal) none)
(define-data-var winner3 (optional principal) none)

(define-read-only (is-level-16)
  (match (contract-call? 'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-store-v0
    get-ata-lvl tx-sender
  )
    lvl (>= lvl u16)
    r false
  )
)

(define-read-only (registered-after-start-date)
  (let (
      ;; the `coords` are `{ x: <burn-block-height>, y: <stacks-block-height> }`
      (coords (unwrap!
        (contract-call? 'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-store-v0
          get-coords tx-sender
        )
        false
      ))
      (registration-block-height (get y coords))
      (registration-time (unwrap! (get-stacks-block-info? time registration-block-height) false))
    )
    (>= registration-time START)
  )
)

(define-private (send-reward
    (amount uint)
    (to principal)
  )
  (as-contract?
    ((with-ft 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token "sbtc-token"
      amount
    ))
    (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
      transfer amount current-contract to none
    ))
  )
)

(define-private (claim-1)
  (begin
    (var-set winner1 (some tx-sender))
    (send-reward REWARD_1 tx-sender)
  )
)

(define-private (claim-2)
  (begin
    (asserts! (not (is-eq (some tx-sender) (var-get winner1)))
      ERR_SENDER_ALREADY_CLAIMED_REWARD
    )
    (var-set winner2 (some tx-sender))
    (send-reward REWARD_2 tx-sender)
  )
)

(define-private (claim-3)
  (begin
    (asserts! (not (is-eq (some tx-sender) (var-get winner1)))
      ERR_SENDER_ALREADY_CLAIMED_REWARD
    )
    (asserts! (not (is-eq (some tx-sender) (var-get winner2)))
      ERR_SENDER_ALREADY_CLAIMED_REWARD
    )
    (var-set winner3 (some tx-sender))
    (send-reward REWARD_3 tx-sender)
  )
)

(define-public (claim)
  (begin
    (asserts! (is-level-16) ERR_LOWER_THAN_16)
    (asserts! (registered-after-start-date) ERR_REGISTERED_TOO_SOON)
    (asserts! (is-some (var-get winner1)) (claim-1))
    (asserts! (is-some (var-get winner2)) (claim-2))
    (asserts! (is-some (var-get winner3)) (claim-3))
    ERR_ALL_REWARDS_CLAIMED
  )
)

```
