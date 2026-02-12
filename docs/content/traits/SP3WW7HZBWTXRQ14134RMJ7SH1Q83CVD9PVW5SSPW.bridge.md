---
title: "Trait bridge"
draft: true
---
```
;; Cross-Chain Bridge Contract

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))

(define-data-var total-locked uint u0)
(define-map locked-assets principal uint)

(define-read-only (get-locked-amount (user principal))
  (default-to u0 (map-get? locked-assets user))
)

(define-public (lock-asset (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set locked-assets tx-sender (+ (get-locked-amount tx-sender) amount))
    (var-set total-locked (+ (var-get total-locked) amount))
    (ok amount)
  )
)

(define-public (unlock-asset (user principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (try! (as-contract (stx-transfer? amount tx-sender user)))
    (ok amount)
  )
)

```
