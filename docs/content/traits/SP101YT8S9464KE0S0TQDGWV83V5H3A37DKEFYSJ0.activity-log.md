---
title: "Trait activity-log"
draft: true
---
```
;; Activity Log - Record user activities

(define-map activities
  uint
  {
    user: principal,
    action: (string-ascii 50),
    timestamp: uint
  }
)

(define-data-var activity-counter uint u0)

(define-public (log-activity (action (string-ascii 50)))
  (let ((id (var-get activity-counter)))
    (map-set activities id {
      user: tx-sender,
      action: action,
      timestamp: stacks-block-height
    })
    (var-set activity-counter (+ id u1))
    (ok id)
  )
)

(define-read-only (get-activity (id uint))
  (map-get? activities id)
)

```
