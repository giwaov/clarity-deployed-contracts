---
title: "Trait discounts"
draft: true
---
```
;; Discounts
(define-map discounts (string-ascii 20) {percentage: uint, active: bool})
(define-public (create-discount (code (string-ascii 20)) (percentage uint))
  (begin (map-set discounts code {percentage: percentage, active: true}) (ok true)))
(define-read-only (get-discount (code (string-ascii 20)))
  (map-get? discounts code))

```
