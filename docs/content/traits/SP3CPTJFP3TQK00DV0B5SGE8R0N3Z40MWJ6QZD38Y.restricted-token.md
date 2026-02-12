---
title: "Trait restricted-token"
draft: true
---
```
;; restricted-token.clar
;; Token that prevents transfers to blacklisted addresses
(impl-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

(define-fungible-token restricted-token)
(define-map blacklist principal bool)
(define-constant contract-owner tx-sender)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (is-eq tx-sender sender) (err u100))
        (asserts! (is-none (map-get? blacklist sender)) (err u102)) ;; ERR_SENDER_BLACKLISTED
        (asserts! (is-none (map-get? blacklist recipient)) (err u103)) ;; ERR_RECIPIENT_BLACKLISTED
        (try! (ft-transfer? restricted-token amount sender recipient))
        (match memo to-print (print to-print) 0x)
        (ok true)
    )
)

(define-public (add-to-blacklist (user principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err u101))
        (ok (map-set blacklist user true))
    )
)

(define-public (remove-from-blacklist (user principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err u101))
        (ok (map-delete blacklist user))
    )
)

;; SIP-010 boilerplates
(define-read-only (get-name) (ok "Restricted Token"))
(define-read-only (get-symbol) (ok "RES"))
(define-read-only (get-decimals) (ok u6))
(define-read-only (get-balance (who principal)) (ok (ft-get-balance restricted-token who)))
(define-read-only (get-total-supply) (ok (ft-get-supply restricted-token)))
(define-read-only (get-token-uri) (ok none))
(define-public (mint (amount uint) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err u101))
        (ft-mint? restricted-token amount recipient)
    )
)

```
