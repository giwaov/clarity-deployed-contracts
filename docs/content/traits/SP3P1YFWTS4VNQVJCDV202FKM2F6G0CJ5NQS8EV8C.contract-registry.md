---
title: "Trait contract-registry"
draft: true
---
```
;; contract-registry.clar
;; Registry of trusted contract hashes

(define-map trusted-contracts (buff 32) bool)
(define-constant contract-owner tx-sender)

(define-public (add-trusted-contract (hash (buff 32)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err u100))
        (map-set trusted-contracts hash true)
        (ok true)
    )
)

(define-public (remove-trusted-contract (hash (buff 32)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err u100))
        (map-delete trusted-contracts hash)
        (ok true)
    )
)

(define-read-only (is-trusted (hash (buff 32)))
    (default-to false (map-get? trusted-contracts hash))
)

```
