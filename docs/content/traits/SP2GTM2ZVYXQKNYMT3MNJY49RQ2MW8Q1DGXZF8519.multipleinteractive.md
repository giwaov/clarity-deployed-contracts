---
title: "Trait multipleinteractive"
draft: true
---
```
;; SPDX-License-Identifier: MIT
;; High-Frequency Interaction & Points Contract

;; --- DATA ---
(define-map users
  { user: principal }
  {
    points: uint,
    total-interactions: uint
  }
)

;; --- PUBLIC FUNCTIONS ---

;; Allows a user to interact as many times as they want
(define-public (interact)
  (let (
        (user-data (map-get? users { user: tx-sender }))
       )
    (match user-data
        data
        (begin
          (map-set users
            { user: tx-sender }
            {
              points: (+ (get points data) u5), ;; Reward 5 points per interaction
              total-interactions: (+ (get total-interactions data) u1)
            }
          )
          (ok "Interaction successful"))
        
        ;; New user setup on first interaction
        (begin
          (map-set users
            { user: tx-sender }
            { points: u5, total-interactions: u1 }
          )
          (ok "First interaction successful"))
    )
  )
)

;; --- READ ONLY ---

(define-read-only (get-user-stats (user principal))
  (map-get? users { user: user })
)

(define-read-only (get-my-stats)
  (map-get? users { user: tx-sender })
)

```
