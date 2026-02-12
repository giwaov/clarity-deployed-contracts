---
title: "Trait hero-stats"
draft: true
---
```
;; Contract: Hero Stats
;; Description: Stores XP and Level for players.

(define-map hero-data principal { xp: uint, level: uint })

(define-read-only (get-hero (user principal))
    (default-to { xp: u0, level: u1 } (map-get? hero-data user))
)

;; Only the Battle Arena contract can call this function
(define-public (add-xp (user principal) (amount uint))
    (let
        (
            (current (get-hero user))
            (new-xp (+ (get xp current) amount))
        )
        (map-set hero-data user (merge current { xp: new-xp }))
        (ok new-xp)
    )
)
```
