---
title: "Trait university"
draft: true
---
```
;; Contract: University Registry
;; Description: Manages authorized professors.

(define-map professors principal bool)
(define-constant dean tx-sender)

(define-public (add-professor (user principal))
    (begin
        (asserts! (is-eq tx-sender dean) (err u401))
        (ok (map-set professors user true))
    )
)

(define-read-only (is-authorized (user principal))
    (default-to false (map-get? professors user))
)
```
