---
title: "Trait vote-records"
draft: true
---
```
;; Vote Records
(define-map votes {proposal-id: uint, voter: principal} {choice: uint})
(define-public (cast-vote (proposal-id uint) (choice uint))
  (begin (map-set votes {proposal-id: proposal-id, voter: tx-sender} {choice: choice}) (ok true)))
(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes {proposal-id: proposal-id, voter: voter}))

```
