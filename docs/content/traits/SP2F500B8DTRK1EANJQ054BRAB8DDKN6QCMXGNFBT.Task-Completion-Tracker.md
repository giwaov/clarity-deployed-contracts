---
title: "Trait Task-Completion-Tracker"
draft: true
---
```
(define-map tasks principal uint)

(define-public (complete-task)
  (let ((count (default-to u0 (map-get? tasks tx-sender))))
    (begin
      (map-set tasks tx-sender (+ count u1))
      (ok (+ count u1))
    )
  )
)

```
