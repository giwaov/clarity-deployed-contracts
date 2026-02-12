---
title: "Trait goal-tracker"
draft: true
---
```
;; Goal Tracker

(define-map goals
  uint
  { owner: principal, target: uint, progress: uint, completed: bool }
)

(define-data-var counter uint u0)

(define-public (create-goal (target uint))
  (let ((id (var-get counter)))
    (map-set goals id { owner: tx-sender, target: target, progress: u0, completed: false })
    (var-set counter (+ id u1))
    (ok id)
  )
)

(define-public (update-progress (id uint) (amount uint))
  (let ((goal (unwrap! (map-get? goals id) (err u404))))
    (asserts! (is-eq (get owner goal) tx-sender) (err u403))
    (let ((new-progress (+ (get progress goal) amount)))
      (map-set goals id (merge goal { progress: new-progress, completed: (>= new-progress (get target goal)) }))
    )
    (ok true)
  )
)

(define-read-only (get-goal (id uint))
  (map-get? goals id)
)

```
