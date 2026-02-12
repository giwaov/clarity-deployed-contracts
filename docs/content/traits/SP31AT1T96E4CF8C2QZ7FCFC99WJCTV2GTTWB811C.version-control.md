---
title: "Trait version-control"
draft: true
---
```
(define-data-var current-version uint u1)

(define-public (upgrade-version)
    (begin
        (var-set current-version (+ (var-get current-version) u1))
        (ok true)
    )
)

```
