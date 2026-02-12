---
title: "Trait profile"
draft: true
---
```
;; Contract: User Profile
;; Description: Stores user badges.

(define-map user-badges principal (string-ascii 20))

(define-public (claim-badge)
    (let
        (
            ;; Fetch the official badge name from definitions
            (b-name (unwrap-panic (contract-call? .defs get-badge-name)))
        )
        ;; Assign badge to user
        (map-set user-badges tx-sender b-name)
        (ok "Badge Claimed")
    )
)
```
