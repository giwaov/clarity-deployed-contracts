---
title: "Trait token-factory"
draft: true
---
```
;; Token Factory Contract

(define-data-var next-token-id uint u1)

(define-map tokens
  uint
  {
    creator: principal,
    name: (string-ascii 32),
    symbol: (string-ascii 10),
    total-supply: uint
  }
)

(define-read-only (get-token-info (token-id uint))
  (map-get? tokens token-id)
)

(define-public (create-token (name (string-ascii 32)) (symbol (string-ascii 10)))
  (let ((token-id (var-get next-token-id)))
    (map-set tokens token-id {
      creator: tx-sender,
      name: name,
      symbol: symbol,
      total-supply: u0
    })
    (var-set next-token-id (+ token-id u1))
    (ok token-id)
  )
)

```
