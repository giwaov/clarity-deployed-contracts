---
title: "Trait blacklist"
draft: true
---
```
;; simple-blacklist.clar

(define-constant ERR-NOT-OWNER u401)
(define-data-var owner principal tx-sender)
(define-map blacklist {user: principal} {blocked: bool})

(define-read-only (is-blocked (user principal))
  (default-to false (get blocked (map-get? blacklist {user: user}))))

(define-public (block (user principal))
  (if (is-eq tx-sender (var-get owner))
    (begin (map-set blacklist {user: user} {blocked: true}) (ok true))
    (err ERR-NOT-OWNER)))

(define-public (unblock (user principal))
  (if (is-eq tx-sender (var-get owner))
    (begin (map-delete blacklist {user: user}) (ok true))
    (err ERR-NOT-OWNER)))

```
