---
title: "Trait registry-service"
draft: true
---
```
;; registry-service.clar
;; Service discovery registry

(define-map services
    (string-ascii 64)
    { url: (string-ascii 256), status: (string-ascii 20) }
)

(define-public (register-service (name (string-ascii 64)) (url (string-ascii 256)))
    (begin
        (map-set services name { url: url, status: "active" })
        (ok true)
    )
)

(define-public (set-status (name (string-ascii 64)) (status (string-ascii 20)))
    (begin
        (match (map-get? services name)
            svc (map-set services name (merge svc { status: status }))
            false
        )
        (ok true)
    )
)

```
