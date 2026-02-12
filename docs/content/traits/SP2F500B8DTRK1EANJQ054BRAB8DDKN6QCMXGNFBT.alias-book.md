---
title: "Trait alias-book"
draft: true
---
```
(define-map aliases principal (string-ascii 24))

(define-public (set-alias (name (string-ascii 24)))
  (begin
    (map-set aliases tx-sender name)
    (ok name)
  )
)

(define-read-only (get-alias (user principal))
  (map-get? aliases user)
)

```
