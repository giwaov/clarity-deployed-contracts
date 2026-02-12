---
title: "Trait nova-zero-knowledge-verifier"
draft: true
---
```

;; nova-zero-knowledge-verifier.clar
;; Mock ZK proof verification
;; CLARITY VERSION: 2

(define-public (verify-proof (proof (buff 128)) (public-inputs (list 10 uint)))
    (begin
        ;; Always return true for mock
        (ok true)
    )
)

```
