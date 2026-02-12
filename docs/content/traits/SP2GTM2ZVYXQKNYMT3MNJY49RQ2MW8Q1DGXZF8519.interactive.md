---
title: "Trait interactive"
draft: true
---
```
;; SPDX-License-Identifier: MIT
;; Daily Check-in & Points Contract (Fixed for 2026)

;; --- CONSTANTS ---
(define-constant ERR_ALREADY_CHECKED_IN (err u100))

;; --- DATA ---
(define-map users
  { user: principal }
  {
    points: uint,
    streak: uint,
    last-day: uint
  }
)

;; --- PUBLIC FUNCTIONS ---

(define-public (check-in)
  (let (
        ;; burn-block-height tracks Bitcoin blocks (~144/day) accurately
        (current-day (/ burn-block-height u144))
        (user-data (map-get? users { user: tx-sender }))
       )
    (match user-data
        data
        (if (> current-day (get last-day data))
            (begin
              (map-set users
                { user: tx-sender }
                {
                  points: (+ (get points data) u10),
                  streak: (if (is-eq current-day (+ (get last-day data) u1)) ;; FIXED: use is-eq
                            (+ (get streak data) u1)
                            u1),
                  last-day: current-day
                }
              )
              (ok "Check-in successful"))
            ERR_ALREADY_CHECKED_IN)
        ;; First-time user setup
        (begin
          (map-set users
            { user: tx-sender }
            { points: u10, streak: u1, last-day: current-day }
          )
          (ok "First check-in"))
    )
  )
)

;; --- READ ONLY ---

(define-read-only (get-user (user principal))
  (map-get? users { user: user })
)

(define-read-only (get-my-info)
  (map-get? users { user: tx-sender })
)

```
