---
title: "Trait streak-counter"
draft: true
---
```
;; Streak Counter

(define-map streaks
  principal
  { current: uint, longest: uint, lastBlock: uint }
)

(define-public (check-in)
  (let ((s (default-to { current: u0, longest: u0, lastBlock: u0 } (map-get? streaks tx-sender))))
    (let ((new-current (if (<= (- stacks-block-height (get lastBlock s)) u144) (+ (get current s) u1) u1)))
      (map-set streaks tx-sender {
        current: new-current,
        longest: (if (> new-current (get longest s)) new-current (get longest s)),
        lastBlock: stacks-block-height
      })
    )
    (ok true)
  )
)

(define-read-only (get-streak (user principal))
  (default-to { current: u0, longest: u0, lastBlock: u0 } (map-get? streaks user))
)

```
