---
title: "Trait daily-checkin-v2"
draft: true
---
```
(define-map user-stats
  principal
  {
    current-streak: uint,
    max-streak: uint,
    total-checkins: uint
  }
)

(define-read-only (get-user (user principal))
  (map-get? user-stats user)
)

(define-public (check-in)
  (let (
        (caller tx-sender)
        (stats (map-get? user-stats caller))
       )

    (if (is-none stats)
        ;; First check-in
        (begin
          (map-set user-stats caller {
            current-streak: u1,
            max-streak: u1,
            total-checkins: u1
          })
          (ok u1)
        )

        ;; Existing user
        (let (
              (current (get current-streak (unwrap-panic stats)))
              (max (get max-streak (unwrap-panic stats)))
              (total (get total-checkins (unwrap-panic stats)))
              (new-streak (+ current u1))
              (new-max (if (> (+ current u1) max) (+ current u1) max))
             )

          (map-set user-stats caller {
            current-streak: new-streak,
            max-streak: new-max,
            total-checkins: (+ total u1)
          })
          (ok new-streak)
        )
    )
  )
)

```
