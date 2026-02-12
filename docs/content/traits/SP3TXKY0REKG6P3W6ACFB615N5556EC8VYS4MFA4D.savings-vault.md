---
title: "Trait savings-vault"
draft: true
---
```
;; simple-savings-vault.clar
;; Per-user deposit tracking (internal accounting only). STX stays in contract.

(define-constant ERR-INSUFFICIENT u301)

(define-map deposits {user: principal} {amount: uint})

(define-read-only (get-deposit (user principal))
  (default-to u0 (get amount (map-get? deposits {user: user}))))

(define-public (deposit (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (let ((prev (default-to u0 (get amount (map-get? deposits {user: tx-sender})))) )
      (map-set deposits {user: tx-sender} {amount: (+ prev amount)})
      (ok (+ prev amount)))))

(define-public (withdraw (amount uint))
  (let ((prev (default-to u0 (get amount (map-get? deposits {user: tx-sender})))) )
    (if (>= prev amount)
      (begin
        (map-set deposits {user: tx-sender} {amount: (- prev amount)})
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        (ok (- prev amount)))
      (err ERR-INSUFFICIENT))))

```
