---
title: "Trait fungible-token-v7"
draft: true
---
```
(impl-trait .sip-010-trait-v7.sip-010-trait)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))

(define-fungible-token my-token-v7)

(define-public (transfer
    (amount uint)
    (sender principal)
    (recipient principal)
    (memo (optional (buff 34)))
  )
  (begin
    (asserts! (is-eq tx-sender sender) err-not-token-owner)
    (asserts! (not (is-eq sender recipient)) (err u102))
    (asserts! (> amount u0) (err u103))
    (try! (ft-transfer? my-token-v7 amount sender recipient))
    (match memo
      to-print (print to-print)
      0x
    )
    (ok true)
  )
)

(define-read-only (get-name)
  (ok "My Token V7")
)

(define-read-only (get-symbol)
  (ok "MTK2")
)

(define-read-only (get-decimals)
  (ok u6)
)

(define-read-only (get-balance (who principal))
  (ok (ft-get-balance my-token-v7 who))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply my-token-v7))
)

(define-read-only (get-token-uri)
  (ok none)
)

(define-public (mint
    (amount uint)
    (recipient principal)
  )
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> amount u0) (err u104))
    (asserts! (not (is-eq recipient contract-owner)) (err u105))
    (ft-mint? my-token-v7 amount recipient)
  )
)

```
