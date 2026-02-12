---
title: "Trait staging-dao-treasury-v0"
draft: true
---
```
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; dao-treasury
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; ============================================================================
;; TRAITS
;; ============================================================================
(use-trait ft-trait .staging-ft-trait-v0.ft-trait)

;; ============================================================================
;; ERRORS (300xxx prefix for dao-treasury)
;; ============================================================================
(define-constant ERR-AUTH (err u300001))

;; CONSTANTS
(define-constant ZEST-STX-WRAPPER-CONTRACT 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.staging-wstx-v0)

;; ============================================================================
;; PRIVATE FUNCTIONS
;; ============================================================================

;; -- Auth helpers -----------------------------------------------------------

(define-private (check-dao-auth)
  (ok (asserts! (is-eq tx-sender .staging-dao-executor-v0) ERR-AUTH)))

;; ============================================================================
;; PUBLIC FUNCTIONS
;; ============================================================================

;; -- Treasury operations ----------------------------------------------------

(define-public (withdraw (token <ft-trait>) (amount uint) (recipient principal))
  (let ((asset-contract (contract-of token)))
    (try! (check-dao-auth))

    (try! (if (is-eq asset-contract ZEST-STX-WRAPPER-CONTRACT)
      (as-contract? ((with-stx amount))
        (try! (contract-call? token transfer amount tx-sender recipient none)))
      (as-contract? ((with-ft asset-contract "*" amount))
        (try! (contract-call? token transfer amount tx-sender recipient none)))))

    (print {
      action: "dao-treasury-withdraw",
      caller: tx-sender,
      data: {
        token: (contract-of token),
        amount: amount,
        recipient: recipient
      }
    })
    
    (ok true)
  ))

```
