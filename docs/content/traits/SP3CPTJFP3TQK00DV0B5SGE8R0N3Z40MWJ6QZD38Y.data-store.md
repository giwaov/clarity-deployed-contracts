---
title: "Trait data-store"
draft: true
---
```
;; data-store.clar
;; Store arbitrary data

(define-map data principal (buff 2048))

(define-public (store (blob (buff 2048)))
    (ok (map-set data tx-sender blob))
)

(define-read-only (get-data (user principal))
    (map-get? data user)
)

```
