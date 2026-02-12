---
title: "Trait task-manager-v2"
draft: true
---
```
;; task-manager.clar
;; Todo list on chain

(define-map tasks { user: principal, id: uint } (string-utf8 100))

(define-public (add-task (id uint) (desc (string-utf8 100)))
    (ok (map-set tasks { user: tx-sender, id: id } desc))
)

(define-public (delete-task (id uint))
    (ok (map-delete tasks { user: tx-sender, id: id }))
)

```
