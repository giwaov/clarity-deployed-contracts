---
title: "Trait quest-registry-trait-v1"
draft: true
---
```
;; title: quest-registry-trait
;; summary: Interface for the quest registry contract

(define-trait quest-registry-trait
  (
    ;; fetch quest metadata by id
    (get-quest (uint) (response
      {
        name: (string-utf8 64),
        type-id: uint,
        xp-reward: uint,
        badge-uri: (string-utf8 256),
        active: bool
      }
      uint))
    ;; check if quest active
    (quest-is-active (uint) (response bool uint))
    ;; get next quest id counter
    (get-next-quest-id () (response uint uint))
  ))

```
