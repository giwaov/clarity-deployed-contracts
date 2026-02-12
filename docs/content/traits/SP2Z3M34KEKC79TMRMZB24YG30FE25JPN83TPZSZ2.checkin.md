---
title: "Trait checkin"
draft: true
---
```
;; Daily Check-in Contract
(define-data-var counter uint u0)

(define-public (checkin)
    (begin
        (var-set counter (+ (var-get counter) u1))
        (ok true)
    )
)

(define-read-only (getcounter)
    (ok (var-get counter))
)

```
