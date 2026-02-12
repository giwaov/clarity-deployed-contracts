---
title: "Trait license-manager"
draft: true
---
```
;; License Manager
(define-map licenses {license-id: uint} {holder: principal, product: (string-ascii 100), license-type: (string-ascii 30), issued-at: uint, expires-at: uint})
(define-public (issue-license (license-id uint) (product (string-ascii 100)) (license-type (string-ascii 30)) (issued-at uint) (expires-at uint))
  (begin (map-set licenses {license-id: license-id} {holder: tx-sender, product: product, license-type: license-type, issued-at: issued-at, expires-at: expires-at}) (ok true)))
(define-read-only (get-license (license-id uint))
  (map-get? licenses {license-id: license-id}))

```
