---
title: "Trait two-factor"
draft: true
---
```
;; two-factor.clar
;; Mock 2FA

(define-map secrets principal (buff 32))

(define-public (set-secret (hash (buff 32)))
    (ok (map-set secrets tx-sender hash))
)

(define-public (authenticate (code (buff 32)))
    (let
        (
            (hash (unwrap! (map-get? secrets tx-sender) (err u100)))
        )
        (asserts! (is-eq (sha256 code) hash) (err u101))
        (ok true)
    )
)

```
