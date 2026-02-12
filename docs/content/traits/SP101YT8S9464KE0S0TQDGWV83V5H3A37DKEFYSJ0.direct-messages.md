---
title: "Trait direct-messages"
draft: true
---
```
;; Direct Messages
(define-map dms uint {from: principal, to: principal, message: (string-ascii 500)})
(define-data-var dm-id uint u0)
(define-public (send-dm (to principal) (message (string-ascii 500)))
  (let ((id (var-get dm-id)))
    (map-set dms id {from: tx-sender, to: to, message: message})
    (var-set dm-id (+ id u1))
    (ok id)))
(define-read-only (get-dm (id uint))
  (map-get? dms id))

```
