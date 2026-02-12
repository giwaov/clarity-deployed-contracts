---
title: "Trait comtipjar"
draft: true
---
```
;; Community Tip Jar & Leaderboard

(define-map total-tipped principal uint)
(define-data-var top-tipper principal tx-sender)
(define-data-var highest-tip-amount uint u0)

;; Read-only: Check the current Top Tipper
(define-read-only (get-leader)
  {
    leader: (var-get top-tipper),
    total: (var-get highest-tip-amount)
  }
)

;; Read-only: Check a specific user's total tips
(define-read-only (get-user-stats (user principal))
  (default-to u0 (map-get? total-tipped user))
)

;; Public: Send a tip and update the leaderboard
(define-public (tip-jar (amount uint))
  (let (
    (new-total (+ (get-user-stats tx-sender) amount))
  )
    ;; 1. Transfer STX from user to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; 2. Update user's personal total
    (map-set total-tipped tx-sender new-total)
    
    ;; 3. Check if this user is now the new leader
    (if (> new-total (var-get highest-tip-amount))
      (begin
        (var-set top-tipper tx-sender)
        (var-set highest-tip-amount new-total)
        (ok "You are the new leader!"))
      (ok "Tip received, thanks!")
    )
  )
)

```
