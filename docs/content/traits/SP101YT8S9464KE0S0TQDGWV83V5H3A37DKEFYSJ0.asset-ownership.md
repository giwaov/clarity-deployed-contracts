---
title: "Trait asset-ownership"
draft: true
---
```
;; Asset Ownership
(define-map assets uint {owner: principal, asset-type: (string-ascii 30), metadata: (string-ascii 200)})
(define-data-var asset-id uint u0)
(define-public (register-asset (asset-type (string-ascii 30)) (metadata (string-ascii 200)))
  (let ((id (var-get asset-id)))
    (map-set assets id {owner: tx-sender, asset-type: asset-type, metadata: metadata})
    (var-set asset-id (+ id u1))
    (ok id)))
(define-read-only (get-asset (id uint))
  (map-get? assets id))

```
