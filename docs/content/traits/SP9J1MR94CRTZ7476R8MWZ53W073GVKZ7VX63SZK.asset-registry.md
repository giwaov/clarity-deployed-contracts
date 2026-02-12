---
title: "Trait asset-registry"
draft: true
---
```
;; Asset Registry
(define-map assets {asset-id: uint} {owner: principal, name: (string-ascii 100), value: uint, registered-at: uint})
(define-public (register-asset (asset-id uint) (name (string-ascii 100)) (value uint) (registered-at uint))
  (begin (map-set assets {asset-id: asset-id} {owner: tx-sender, name: name, value: value, registered-at: registered-at}) (ok true)))
(define-read-only (get-asset (asset-id uint))
  (map-get? assets {asset-id: asset-id}))

```
