---
title: "Trait nova-character-stats"
draft: true
---
```

;; nova-character-stats.clar
;; Stores RPG stats
;; CLARITY VERSION: 2

(define-map stats
    uint ;; token-id
    {
        level: uint,
        strength: uint,
        magic: uint
    }
)

(define-public (set-stats (id uint) (level uint) (str uint) (mag uint))
    (begin
        ;; Auth check omitted
        (map-set stats id {level: level, strength: str, magic: mag})
        (ok true)
    )
)

(define-read-only (get-stats (id uint))
    (map-get? stats id)
)

```
