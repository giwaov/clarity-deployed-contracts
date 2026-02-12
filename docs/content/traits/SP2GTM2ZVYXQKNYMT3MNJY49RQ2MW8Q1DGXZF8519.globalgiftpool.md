---
title: "Trait globalgiftpool"
draft: true
---
```
;; Global Gift Pool Contract
;; Allows users to deposit STX and others to claim a fixed "gift"

;; Global total STX currently in the pool
(define-data-var pool-total uint u0)

;; Tracking how many times each user has claimed a gift
(define-map claim-count principal uint)

;; Constant for the gift size (0.1 STX or 100,000 micro-STX)
(define-constant GIFT_SIZE u100000)

;; Public function: Deposit STX into the pool
(define-public (deposit (amount uint))
  (begin
    ;; Transfer STX from user to the contract address
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    ;; Update the global total
    (var-set pool-total (+ (var-get pool-total) amount))
    (ok "Deposit successful!")
  )
)

;; Public function: Claim a fixed gift from the pool
(define-public (claim-gift)
  (let (
    (current-pool (var-get pool-total))
    (user-claims (default-to u0 (map-get? claim-count tx-sender)))
  )
    ;; 1. Check if the pool has enough STX
    (asserts! (>= current-pool GIFT_SIZE) (err u500))
    ;; 2. Limit: Each user can only claim 3 times total
    (asserts! (< user-claims u3) (err u403))

    ;; Transfer gift from contract back to the user
    (try! (as-contract (stx-transfer? GIFT_SIZE (as-contract tx-sender) tx-sender)))
    
    ;; Update pool total and user's claim count
    (var-set pool-total (- current-pool GIFT_SIZE))
    (map-set claim-count tx-sender (+ user-claims u1))
    
    (ok "Gift claimed!")
  )
)

;; Read-only: Check the current pool balance and your claim history
(define-read-only (get-info (user principal))
  {
    total-in-pool: (var-get pool-total),
    your-claims: (default-to u0 (map-get? claim-count user))
  }
)

```
