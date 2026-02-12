---
title: "Trait resource-tag"
draft: true
---
```
(define-map tags uint (string-ascii 32))
(define-data-var next uint u0)

(define-public (tag (label (string-ascii 32)))
  (let ((id (var-get next)))
    (begin
      (map-set tags id label)
      (var-set next (+ id u1))
      (ok id)
    )
  )
)

```
