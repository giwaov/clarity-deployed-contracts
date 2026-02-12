---
title: "Trait pausable"
draft: true
---
```
;; simple-pausable.clar

(define-constant ERR-NOT-OWNER u401)
(define-constant ERR-PAUSED u402)

(define-data-var owner principal tx-sender)
(define-data-var paused bool false)

(define-read-only (is-paused) (var-get paused))

(define-public (set-paused (p bool))
  (if (is-eq tx-sender (var-get owner))
    (begin (var-set paused p) (ok true))
    (err ERR-NOT-OWNER)))

(define-public (do-something)
  (if (var-get paused)
    (err ERR-PAUSED)
    (ok {sender: tx-sender, height: burn-block-height})))

```
