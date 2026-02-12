---
title: "Trait nova-address-book"
draft: true
---
```

;; nova-address-book.clar
;; Address registry
;; CLARITY VERSION: 2

(define-map names principal (string-ascii 32))

(define-public (set-name (name (string-ascii 32)))
    (begin
        (map-set names tx-sender name)
        (ok true)
    )
)

(define-read-only (get-name (user principal))
    (map-get? names user)
)

```
