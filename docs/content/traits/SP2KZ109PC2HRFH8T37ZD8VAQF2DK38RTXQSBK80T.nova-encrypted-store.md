---
title: "Trait nova-encrypted-store"
draft: true
---
```

;; nova-encrypted-store.clar
;; Store encrypted data hashes
;; CLARITY VERSION: 2

(define-map store
    {user: principal, key: (string-ascii 32)}
    (buff 256) ;; Encrypted data or hash
)

(define-public (store-data (key (string-ascii 32)) (data (buff 256)))
    (begin
        (map-set store {user: tx-sender, key: key} data)
        (ok true)
    )
)

(define-read-only (get-data (user principal) (key (string-ascii 32)))
    (map-get? store {user: user, key: key})
)

```
