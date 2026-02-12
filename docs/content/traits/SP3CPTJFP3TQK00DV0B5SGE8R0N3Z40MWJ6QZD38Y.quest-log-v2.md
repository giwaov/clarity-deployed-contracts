---
title: "Trait quest-log-v2"
draft: true
---
```
;; quest-log.clar
;; Track user quests

(define-map quests { user: principal, quest-id: uint } { status: (string-ascii 10), completed-at: uint })

(define-public (start-quest (quest-id uint))
    (begin
        (asserts! (> quest-id u0) (err u100))
        (ok (map-set quests { user: tx-sender, quest-id: quest-id } { status: "active", completed-at: u0 }))
    )
)

(define-public (complete-quest (quest-id uint))
    (begin
        (asserts! (> quest-id u0) (err u100))
        ;; Logic to verify completion
        (ok (map-set quests { user: tx-sender, quest-id: quest-id } { status: "completed", completed-at: block-height }))
    )
)

(define-read-only (get-quest (user principal) (quest-id uint))
    (ok (map-get? quests { user: user, quest-id: quest-id }))
)

```
