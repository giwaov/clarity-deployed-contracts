---
title: "Trait token-registry"
draft: true
---
```
;; Token Registry
(define-map tokens {token-id: uint} {name: (string-ascii 50), symbol: (string-ascii 10), owner: principal, total-supply: uint})
(define-public (register-token (token-id uint) (name (string-ascii 50)) (symbol (string-ascii 10)) (total-supply uint))
  (begin (map-set tokens {token-id: token-id} {name: name, symbol: symbol, owner: tx-sender, total-supply: total-supply}) (ok true)))
(define-read-only (get-token (token-id uint))
  (map-get? tokens {token-id: token-id}))

```
