---
title: "Trait access-tokens"
draft: true
---
```
;; Access Tokens
(define-map tokens (string-ascii 50) {owner: principal, valid: bool})
(define-public (create-token (token (string-ascii 50)))
  (begin (map-set tokens token {owner: tx-sender, valid: true}) (ok true)))
(define-read-only (is-valid-token (token (string-ascii 50)))
  (default-to false (get valid (map-get? tokens token))))

```
