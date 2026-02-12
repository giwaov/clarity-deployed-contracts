---
title: "Trait validator-set"
draft: true
---
```
;; Validator Set Contract

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))

(define-map validators principal bool)

(define-read-only (is-validator (address principal))
  (default-to false (map-get? validators address))
)

(define-public (add-validator (validator principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set validators validator true)
    (ok true)
  )
)

(define-public (remove-validator (validator principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-delete validators validator)
    (ok true)
  )
)

```
