---
title: "Trait store"
draft: true
---
```
;; Simple Record Storage Contract

;; Store records with name and age
(define-map records principal { name: (string-ascii 50), age: uint })

;; Save a record
(define-public (save-record (name (string-ascii 50)) (age uint))
  (begin
    (map-set records tx-sender { name: name, age: age })
    (ok true)
  )
)

;; Get a record
(define-read-only (get-record (user principal))
  (map-get? records user)
)
```
