---
title: "Trait tip-jar-stx"
draft: true
---
```
;; tip-jar-stx.clar
;; Anyone can tip STX to the jar; owner can withdraw.

(define-constant ERR-NOT-OWNER u401)

(define-data-var owner principal tx-sender)

(define-read-only (get-owner) (ok (var-get owner)))
(define-read-only (get-balance)
  (ok (stx-get-balance (as-contract tx-sender))))

(define-public (tip (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (ok amount)))

(define-public (withdraw (amount uint))
  (if (is-eq tx-sender (var-get owner))
    (begin
      (try! (as-contract (stx-transfer? amount tx-sender (var-get owner))))
      (ok amount))
    (err ERR-NOT-OWNER)))

```
