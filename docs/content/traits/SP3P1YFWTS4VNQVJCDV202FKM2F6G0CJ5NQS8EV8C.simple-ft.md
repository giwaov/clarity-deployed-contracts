---
title: "Trait simple-ft"
draft: true
---
```
;; simple-ft.clar
;; A simple SIP-010 fungible token
(use-trait sip-010-trait .sip-010-trait.sip-010-trait)
(impl-trait .sip-010-trait.sip-010-trait)

(define-fungible-token my-token)
(define-constant contract-owner tx-sender)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (is-eq tx-sender sender) (err u100))
        (try! (ft-transfer? my-token amount sender recipient))
        (match memo to-print (print to-print) 0x)
        (ok true)
    )
)

(define-read-only (get-name)
    (ok "My Token")
)

(define-read-only (get-symbol)
    (ok "MYT")
)

(define-read-only (get-decimals)
    (ok u6)
)

(define-read-only (get-balance (who principal))
    (ok (ft-get-balance my-token who))
)

(define-read-only (get-total-supply)
    (ok (ft-get-supply my-token))
)

(define-read-only (get-token-uri)
    (ok none)
)

(define-public (mint (amount uint) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err u101))
        (ft-mint? my-token amount recipient)
    )
)

```
