---
title: "Trait platform-stats"
draft: true
---
```
;; Platform Stats
(define-data-var total-users uint u0)
(define-data-var total-services uint u0)
(define-data-var total-transactions uint u0)
(define-public (update-platform-stats (users uint) (services uint) (transactions uint))
  (begin
    (var-set total-users users)
    (var-set total-services services)
    (var-set total-transactions transactions)
    (ok true)))
(define-read-only (get-platform-stats)
  (ok {users: (var-get total-users), services: (var-get total-services), transactions: (var-get total-transactions)}))

```
