---
title: "Trait property-registry"
draft: true
---
```
;; Property Registry
(define-map properties {property-id: uint} {owner: principal, address: (string-ascii 200), value: uint, registered-at: uint, verified: bool})
(define-public (register-property (property-id uint) (address (string-ascii 200)) (value uint) (registered-at uint) (verified bool))
  (begin (map-set properties {property-id: property-id} {owner: tx-sender, address: address, value: value, registered-at: registered-at, verified: verified}) (ok true)))
(define-read-only (get-property (property-id uint))
  (map-get? properties {property-id: property-id}))

```
