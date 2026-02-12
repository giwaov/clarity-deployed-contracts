---
title: "Trait core-registry"
draft: true
---
```
(define-map extensions principal bool)

(define-public (set-extension (extension principal) (enabled bool))
    (begin
        (asserts! (is-eq tx-sender (as-contract tx-sender)) (err u401))
        (ok (map-set extensions extension enabled))))
```
