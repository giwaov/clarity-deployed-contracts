---
title: "Trait queues"
draft: true
---
```
;; Queues
(define-map queues {queue-id: uint, user: principal} {number: uint, status: (string-ascii 20)})
(define-public (join-queue (queue-id uint) (number uint))
  (begin (map-set queues {queue-id: queue-id, user: tx-sender} {number: number, status: "waiting"}) (ok true)))
(define-read-only (get-queue-status (queue-id uint) (user principal))
  (map-get? queues {queue-id: queue-id, user: user}))

```
