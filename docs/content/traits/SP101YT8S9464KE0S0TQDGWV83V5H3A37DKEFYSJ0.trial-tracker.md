---
title: "Trait trial-tracker"
draft: true
---
```
;; Trial Tracker - Track free trials

(define-map trials
  { user: principal, creator: principal }
  {
    started-at: uint,
    expires-at: uint,
    active: bool
  }
)

(define-public (start-trial (creator principal) (duration uint))
  (begin
    (map-set trials { user: tx-sender, creator: creator } {
      started-at: stacks-block-height,
      expires-at: (+ stacks-block-height duration),
      active: true
    })
    (ok true)
  )
)

(define-public (end-trial (creator principal))
  (let ((trial (unwrap! (map-get? trials { user: tx-sender, creator: creator }) (err u404))))
    (map-set trials { user: tx-sender, creator: creator }
      (merge trial { active: false }))
    (ok true)
  )
)

(define-read-only (get-trial (user principal) (creator principal))
  (map-get? trials { user: user, creator: creator })
)

(define-read-only (is-trial-active (user principal) (creator principal))
  (match (map-get? trials { user: user, creator: creator })
    trial (and (get active trial) (< stacks-block-height (get expires-at trial)))
    false
  )
)

```
