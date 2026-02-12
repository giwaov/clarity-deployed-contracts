---
title: "Trait registry-v2"
draft: true
---
```
;; Registry Contract V2
(define-map registry (string-ascii 64) principal)

(define-public (register (name (string-ascii 64)))
  (ok (map-set registry name tx-sender)))

(define-read-only (lookup (name (string-ascii 64)))
  (map-get? registry name))

(define-public (unregister (name (string-ascii 64)))
  (ok (map-delete registry name)))
```
