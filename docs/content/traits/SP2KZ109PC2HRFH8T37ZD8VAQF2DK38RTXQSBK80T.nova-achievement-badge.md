---
title: "Trait nova-achievement-badge"
draft: true
---
```

;; nova-achievement-badge.clar
;; Simple badges
;; CLARITY VERSION: 2

(define-map badges
    {user: principal, badge-id: uint}
    bool
)

(define-public (award-badge (user principal) (badge-id uint))
    (begin
        ;; Only admin
        (map-set badges {user: user, badge-id: badge-id} true)
        (ok true)
    )
)

(define-read-only (has-badge (user principal) (badge-id uint))
    (default-to false (map-get? badges {user: user, badge-id: badge-id}))
)

```
