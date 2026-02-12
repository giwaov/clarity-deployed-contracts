---
title: "Trait ststxbtc-balance"
draft: true
---
```
(define-constant zstSTXbtc u11)

(define-constant ERR-NO-POSITION (err u900003))

;; Helper: Find specific asset amount in collateral list
(define-private (find-collateral-amount-iter
  (entry { aid: uint, amount: uint })
  (acc { target: uint, amount: uint }))
  (if (is-eq (get aid entry) (get target acc))
      { target: (get target acc), amount: (get amount entry) }
      acc))

;; ---------------------------------------------------------------------------
;; get-user-ststxbtc-balances
;; ---------------------------------------------------------------------------
;; Returns user's stSTXbtc holdings across vault and market-vault
;; Includes both stSTXbtc in vault and and zstSTXbtc (vault token) used as collateral
(define-read-only (get-user-ststxbtc-balances (account principal))
  (let (
    (vault-shares (unwrap-panic (contract-call? .vault-ststxbtc get-balance account)))
    (vault-underlying (unwrap-panic (contract-call? .vault-ststxbtc convert-to-assets vault-shares)))
    (enabled-mask (contract-call? .assets get-bitmap))

    ;; Get zstSTXbtc collateral (vault token) and convert to underlying
    (market-zststxbtc-shares
      (match (contract-call? .market-vault get-position account enabled-mask)
        position
          (get amount (fold find-collateral-amount-iter
                           (get collateral position)
                           {target: zstSTXbtc, amount: u0}))
        err-no-position u0))

    (market-zststxbtc-underlying (unwrap-panic (contract-call? .vault-ststxbtc convert-to-assets market-zststxbtc-shares)))

    (total (+ vault-underlying market-zststxbtc-underlying)))

    (ok total)))

```
