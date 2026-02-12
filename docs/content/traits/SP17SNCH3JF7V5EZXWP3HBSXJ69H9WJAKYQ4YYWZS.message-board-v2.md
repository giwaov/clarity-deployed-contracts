---
title: "Trait message-board-v2"
draft: true
---
```
;; Message Board contract

(define-map messages { user: principal } { msg: (string-ascii 140) })

(define-public (set-message (msg (string-ascii 140)))
  (begin
    (map-set messages { user: tx-sender } { msg: msg })
    (ok true)))

(define-read-only (get-message (user principal))
  (map-get? messages { user: user }))

```
