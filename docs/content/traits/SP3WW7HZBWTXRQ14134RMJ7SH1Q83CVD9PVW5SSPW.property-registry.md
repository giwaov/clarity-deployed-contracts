---
title: "Trait property-registry"
draft: true
---
```
;; Property Registry

(define-data-var next-property-id uint u1)

(define-map properties uint { owner: principal, value: uint, location: (string-ascii 64) })

(define-public (register-property (value uint) (location (string-ascii 64)))
  (let ((property-id (var-get next-property-id)))
    (map-set properties property-id { owner: tx-sender, value: value, location: location })
    (var-set next-property-id (+ property-id u1))
    (ok property-id)
  )
)

```
