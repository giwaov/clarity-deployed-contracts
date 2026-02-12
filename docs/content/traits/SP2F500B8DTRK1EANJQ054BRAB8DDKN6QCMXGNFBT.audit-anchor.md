---
title: "Trait audit-anchor"
draft: true
---
```
(define-map audits uint (buff 32))
(define-data-var next-id uint u0)

(define-public (anchor (hash (buff 32)))
  (let ((id (var-get next-id)))
    (begin
      (map-set audits id hash)
      (var-set next-id (+ id u1))
      (ok id)
    )
  )
)

```
