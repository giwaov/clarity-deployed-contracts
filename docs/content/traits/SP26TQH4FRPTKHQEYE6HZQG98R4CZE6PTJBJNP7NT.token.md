---
title: "Trait token"
draft: true
---
```
;; --------------------------------------------------
;; SIP-010 Fungible Token
;; --------------------------------------------------

(define-fungible-token stacks-token)

;; Errors
(define-constant err-not-owner (err u100))
(define-constant err-not-authorized (err u101))

;; Owner
(define-data-var owner principal tx-sender)

;; --------------------------------------------------
;; SIP-010 Required Read-Only Functions
;; --------------------------------------------------

(define-read-only (get-name)
  (ok "Stacks Token")
)

(define-read-only (get-symbol)
  (ok "STK")
)

(define-read-only (get-decimals)
  (ok u6)
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply stacks-token))
)

(define-read-only (get-balance (who principal))
  (ok (ft-get-balance stacks-token who))
)

;; --------------------------------------------------
;; SIP-010 Required Public Function
;; --------------------------------------------------

(define-public (transfer (amount uint) (sender principal) (recipient principal))
  (if (is-eq tx-sender sender)
      (begin
        (try! (ft-transfer? stacks-token amount sender recipient))
        (ok true)
      )
      err-not-authorized
  )
)

;; --------------------------------------------------
;; Mint (Owner Only)
;; --------------------------------------------------

(define-public (mint (amount uint) (recipient principal))
  (if (is-eq tx-sender (var-get owner))
      (begin
        (try! (ft-mint? stacks-token amount recipient))
        (ok true)
      )
      err-not-owner
  )
)

```
