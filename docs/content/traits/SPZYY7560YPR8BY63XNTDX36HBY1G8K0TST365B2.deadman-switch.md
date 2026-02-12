---
title: "Trait deadman-switch"
draft: true
---
```
;; deadman-switch.clar
;; Owner must "ping" periodically; if they don't, a beneficiary can take over.

(define-constant ERR-NOT-OWNER u401)
(define-constant ERR-TOO-EARLY u402)

(define-data-var owner principal tx-sender)
(define-data-var beneficiary principal tx-sender)
(define-data-var last-ping uint burn-block-height)
(define-constant TIMEOUT u50)

(define-read-only (get-state)
  (ok {owner: (var-get owner), beneficiary: (var-get beneficiary), last-ping: (var-get last-ping)}))

(define-public (set-beneficiary (b principal))
  (if (is-eq tx-sender (var-get owner))
    (begin (var-set beneficiary b) (ok true))
    (err ERR-NOT-OWNER)))

(define-public (ping)
  (if (is-eq tx-sender (var-get owner))
    (begin (var-set last-ping burn-block-height) (ok burn-block-height))
    (err ERR-NOT-OWNER)))

(define-public (claim)
  (let ((lp (var-get last-ping)))
    (if (>= (- burn-block-height lp) TIMEOUT)
      (if (is-eq tx-sender (var-get beneficiary))
        (begin
          (var-set owner (var-get beneficiary))
          (ok true))
        (err ERR-NOT-OWNER))
      (err ERR-TOO-EARLY))))

```
