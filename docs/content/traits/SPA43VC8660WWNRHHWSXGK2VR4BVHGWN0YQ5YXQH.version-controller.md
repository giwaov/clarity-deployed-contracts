---
title: "Trait version-controller"
draft: true
---
```
;; version-controller.clar
;; Tracks version history of system components

(define-map module-versions
    (string-ascii 64)
    { major: uint, minor: uint, patch: uint }
)

(define-public (update-version (module (string-ascii 64)) (major uint) (minor uint) (patch uint))
    (begin
        (map-set module-versions module { major: major, minor: minor, patch: patch })
        (ok true)
    )
)

(define-read-only (get-version (module (string-ascii 64)))
    (map-get? module-versions module)
)

```
