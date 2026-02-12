---
title: "Trait package-builder"
draft: true
---
```
;; Service Bundles - Bundle services
(define-map bundles uint {creator: principal, name: (string-ascii 100), price: uint})
(define-data-var bundle-id uint u0)

(define-public (create-bundle (name (string-ascii 100)) (price uint))
  (let ((id (var-get bundle-id)))
    (map-set bundles id {creator: tx-sender, name: name, price: price})
    (var-set bundle-id (+ id u1))
    (ok id)))

(define-read-only (get-bundle (id uint))
  (map-get? bundles id))

```
