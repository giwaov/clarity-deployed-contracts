---
title: "Trait One-Time-Claim-Vault"
draft: true
---
```
(define-map claims principal bool)
(define-constant err-already-claimed (err u401))

(define-public (claim)
  (if (is-some (map-get? claims tx-sender))
      err-already-claimed
      (begin
        (map-set claims tx-sender true)
        (ok true)
      )
  )
)

(define-read-only (has-claimed (user principal))
  (is-some (map-get? claims user))
)

```
