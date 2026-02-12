---
title: "Trait qwer"
draft: true
---
```
;; Simple Activity Counter Contract
;; Purpose: Generate network activity by calling increment from different wallets

(define-data-var counter uint u0)
(define-data-var last-caller (optional principal) none)

(define-public (increment)
    (begin
        (var-set counter (+ (var-get counter) u1))
        (var-set last-caller (some tx-sender))
        (print { event: "incremented", caller: tx-sender, value: (var-get counter) })
        (ok (var-get counter))
    )
)

(define-read-only (get-counter)
    (ok (var-get counter))
)

(define-read-only (get-last-caller)
    (ok (var-get last-caller))
)
```
