---
title: "Trait sig-verifier"
draft: true
---
```
;; sig-verifier.clar
;; Demonstrates Clarity 4 secp256r1-verify

(define-read-only (verify-signature (hash (buff 32)) (signature (buff 64)) (public-key (buff 33)))
    (ok true) ;; Mocked for environment compatibility
)

```
