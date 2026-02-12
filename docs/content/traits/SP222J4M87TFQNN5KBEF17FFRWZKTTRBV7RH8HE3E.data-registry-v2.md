---
title: "Trait data-registry-v2"
draft: true
---
```
(define-map data-store principal (string-utf8 256))

(define-public (set-data (data (string-utf8 256)))
    (begin
        (map-set data-store tx-sender data)
        (ok true)
    )
)

(define-read-only (get-data (user principal))
    (ok (map-get? data-store user))
)

```
