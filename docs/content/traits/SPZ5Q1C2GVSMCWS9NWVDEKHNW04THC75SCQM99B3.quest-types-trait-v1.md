---
title: "Trait quest-types-trait-v1"
draft: true
---
```
;; title: quest-types-trait
;; summary: Interface for quest type catalog

(define-trait quest-types-trait
  (
    (get-type (uint) (response
      {
        name: (string-utf8 64),
        description: (optional (string-utf8 256)),
        active: bool
      }
      uint))
    (is-type-active (uint) (response bool uint))
    (get-next-type-id () (response uint uint))
  ))

```
