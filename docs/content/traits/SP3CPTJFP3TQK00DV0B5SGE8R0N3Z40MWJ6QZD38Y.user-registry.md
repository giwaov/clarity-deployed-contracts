---
title: "Trait user-registry"
draft: true
---
```
;; user-registry.clar
;; Simple user profile registry

(define-map profiles principal { name: (string-ascii 50), bio: (string-utf8 200) })

(define-read-only (get-profile (user principal))
    (map-get? profiles user)
)

(define-public (register (name (string-ascii 50)) (bio (string-utf8 200)))
    (begin
        (map-set profiles tx-sender { name: name, bio: bio })
        (ok true)
    )
)

(define-public (update-bio (new-bio (string-utf8 200)))
    (let
        (
            (current-profile (unwrap! (map-get? profiles tx-sender) (err u404)))
        )
        (map-set profiles tx-sender (merge current-profile { bio: new-bio }))
        (ok true)
    )
)

```
