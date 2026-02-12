---
title: "Trait ip-whitelist"
draft: true
---
```
;; IP Whitelist
(define-map whitelist (string-ascii 50) {approved: bool, user: principal})
(define-public (add-to-whitelist (ip (string-ascii 50)))
  (begin (map-set whitelist ip {approved: true, user: tx-sender}) (ok true)))
(define-read-only (is-whitelisted (ip (string-ascii 50)))
  (default-to false (get approved (map-get? whitelist ip))))

```
