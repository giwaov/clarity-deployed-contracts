---
title: "Trait capped-token"
draft: true
---
```
;; capped-token.clar
;; Token with a hard cap on supply
(impl-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

(define-fungible-token capped-token u1000000) ;; Hard cap defined here
(define-constant contract-owner tx-sender)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (is-eq tx-sender sender) (err u100))
        (try! (ft-transfer? capped-token amount sender recipient))
        (match memo to-print (print to-print) 0x)
        (ok true)
    )
)

(define-public (mint (amount uint) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err u101))
        ;; ft-mint? will automatically fail if it exceeds the defined cap
        (ft-mint? capped-token amount recipient)
    )
)

;; SIP-010 boilerplates
(define-read-only (get-name) (ok "Capped Token"))
(define-read-only (get-symbol) (ok "CAP"))
(define-read-only (get-decimals) (ok u6))
(define-read-only (get-balance (who principal)) (ok (ft-get-balance capped-token who)))
(define-read-only (get-total-supply) (ok (ft-get-supply capped-token)))
(define-read-only (get-token-uri) (ok none))

```
