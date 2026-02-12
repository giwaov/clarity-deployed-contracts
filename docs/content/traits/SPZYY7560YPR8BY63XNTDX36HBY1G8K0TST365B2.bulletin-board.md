---
title: "Trait bulletin-board"
draft: true
---
```
;; bulletin-board.clar

(define-map messages {user: principal} {msg: (string-ascii 140)})

(define-public (publish-note (msg (string-ascii 140)))
  (begin
    (map-set messages {user: tx-sender} {msg: msg})
    (ok true)))

(define-read-only (get-message (user principal))
  (map-get? messages {user: user}))

```
