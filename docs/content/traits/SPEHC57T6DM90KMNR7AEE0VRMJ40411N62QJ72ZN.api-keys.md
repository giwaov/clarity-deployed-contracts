---
title: "Trait api-keys"
draft: true
---
```
;; API Keys
(define-map api-keys (string-ascii 50) {owner: principal, active: bool})
(define-public (register-key (key (string-ascii 50)))
  (begin (map-set api-keys key {owner: tx-sender, active: true}) (ok true)))
(define-read-only (is-active-key (key (string-ascii 50)))
  (default-to false (get active (map-get? api-keys key))))

```
