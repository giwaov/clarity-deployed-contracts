---
title: "Trait test-trading-hbtc-v6-1"
draft: true
---
```
;; @contract Trading 
;; @version 0.2

(use-trait ft 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-ft-trait.ft-trait)
;; Use staging traits for Zest v2 staging mainnet integration
(use-trait zest-market 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-market-trait.market-trait)
(use-trait zest-vault 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-vault-traits.tokenized-vault)
(use-trait hbtc-vault-trait .test-vault-trait-v6.vault-trait)
(use-trait staking-trait 'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.staking-trait-v1.staking-trait)
(use-trait staking-silo-trait 'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.staking-silo-trait-v1.staking-silo-trait)

;;-------------------------------------
;; Constants
;;-------------------------------------

(define-constant ERR_INVALID_AMOUNT (err u120001))
(define-constant ERR_INVALID_TOKEN (err u120002))

(define-constant usdh-token 'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.usdh-token-v1)

;; @desc - Borrows asset from Zest v2 market and stakes it in Hermetica
(define-public (zest-open
  (market <zest-market>) (staking <staking-trait>)
  (borrow-token <ft>)
  (borrow-amount uint)
  (price-feed-1 (optional (buff 8192))) (price-feed-2 (optional (buff 8192))))
  (begin
    (try! (contract-call? .test-hq-vaults-v6 check-is-trader contract-caller))
    (asserts! (> borrow-amount u0) ERR_INVALID_AMOUNT)
    ;; Validate that borrow token is the canonical borrow token
    (asserts! (is-eq (contract-of borrow-token) usdh-token) ERR_INVALID_TOKEN)
    ;; Borrow asset from Zest v2 market
    (try! (contract-call? .test-zest-interface-hbtc-v6-1 zest-borrow market borrow-token borrow-amount price-feed-1 price-feed-2))
    ;; Stake the borrowed asset into Hermetica
    (try! (contract-call? .test-hermetica-interface-hbtc-v6 hermetica-stake borrow-amount staking))
    (print { action: "zest-open", user: contract-caller, data: { market: market, staking: staking, borrow: { token: borrow-token, amount: borrow-amount } } })
    (ok true)
  )
)

;; @desc - Unstakes asset from Hermetica and repays loan to Zest v2 market
(define-public (zest-close
  (market <zest-market>) (staking <staking-trait>) (staking-silo <staking-silo-trait>) 
  (repay-token <ft>)
  (unstake-amount uint)
  (price-feed-1 (optional (buff 8192))) (price-feed-2 (optional (buff 8192))))
  (begin
    (try! (contract-call? .test-hq-vaults-v6 check-is-trader contract-caller))
    (asserts! (> unstake-amount u0) ERR_INVALID_AMOUNT)
    (let (
      ;; Unstake asset from Hermetica (instant withdrawal)
      (repay-amount (try! (contract-call? .test-hermetica-interface-hbtc-v6 hermetica-unstake-and-withdraw unstake-amount staking staking-silo))))
      ;; Validate that repay token is the canonical borrow token
      (asserts! (is-eq (contract-of repay-token) usdh-token) ERR_INVALID_TOKEN)
      ;; Repay loan to Zest v2 market
      (try! (contract-call? .test-zest-interface-hbtc-v6-1 zest-repay market repay-token repay-amount price-feed-1 price-feed-2))

      (print { action: "zest-close", user: contract-caller, data: { market: market, staking: staking, staking-silo: staking-silo, unstake-amount: unstake-amount, repay: { token: repay-token, amount: repay-amount } } })
      (ok true)
    )
  )
)

;;=====================================
;; DIRECT PATH (Collateral Asset)
;;=====================================

;;-------------------------------------
;; Open Position - Direct Path
;;-------------------------------------

;; @desc - Opens a leveraged position using direct collateral
(define-public (zest-add-open
  (market <zest-market>) (staking <staking-trait>) (collateral-token <ft>) (borrow-token <ft>)
  (collateral-amount uint) (borrow-amount uint)
  (price-feed-1 (optional (buff 8192))) (price-feed-2 (optional (buff 8192))))
  (begin
    (try! (contract-call? .test-hq-vaults-v6 check-is-trader contract-caller))
    (asserts! (> collateral-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> borrow-amount u0) ERR_INVALID_AMOUNT)

    ;; Step 1: Add collateral directly
    (try! (contract-call? .test-zest-interface-hbtc-v6-1 zest-collateral-add market collateral-token collateral-amount price-feed-1 price-feed-2))

    ;; Step 2: Borrow asset and stake it in Hermetica
    ;; Validate that borrow token is the canonical borrow token
    (asserts! (is-eq (contract-of borrow-token) usdh-token) ERR_INVALID_TOKEN)
    ;; Borrow asset from Zest v2 market
    (try! (contract-call? .test-zest-interface-hbtc-v6-1 zest-borrow market borrow-token borrow-amount none none))
    ;; Stake the borrowed asset into Hermetica
    (try! (contract-call? .test-hermetica-interface-hbtc-v6 hermetica-stake borrow-amount staking))

    (print { action: "zest-add-open", user: contract-caller, data: { market: market, staking: staking, collateral: { token: collateral-token, amount: collateral-amount }, borrow: { token: borrow-token, amount: borrow-amount } } })
    (ok true)
  )
)

;;-------------------------------------
;; Close Position - Direct Path
;;-------------------------------------

;; @desc - Closes a leveraged position using direct collateral
(define-public (zest-close-remove
  (market <zest-market>) (staking <staking-trait>) (staking-silo <staking-silo-trait>) (hbtc-vault <hbtc-vault-trait>)
  (collateral-token <ft>) (repay-token <ft>)
  (unstake-amount uint) (collateral-amount uint)
  (claim-ids (list 1000 uint))
  (price-feed-1 (optional (buff 8192))) (price-feed-2 (optional (buff 8192))))
  (begin
    (try! (contract-call? .test-hq-vaults-v6 check-is-trader contract-caller))
    (asserts! (> unstake-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> collateral-amount u0) ERR_INVALID_AMOUNT)

    ;; Step 1: Unstake and repay loan
    (let (
      ;; Unstake asset from Hermetica (instant withdrawal)
      (repay-amount (try! (contract-call? .test-hermetica-interface-hbtc-v6 hermetica-unstake-and-withdraw unstake-amount staking staking-silo))))

      ;; Validate that repay token is the canonical borrow token
      (asserts! (is-eq (contract-of repay-token) usdh-token) ERR_INVALID_TOKEN)
      ;; Repay loan to Zest v2 market
      (try! (contract-call? .test-zest-interface-hbtc-v6-1 zest-repay market repay-token repay-amount price-feed-1 price-feed-2))

      ;; Step 2: Remove collateral
      (try! (contract-call? .test-zest-interface-hbtc-v6-1 zest-collateral-remove market collateral-token collateral-amount none none))
      
      ;; Step 3: Optional - Fund claims with collateral now in reserve
      (if (> (len claim-ids) u0)
        (begin
          (try! (contract-call? .test-hq-vaults-v6 check-is-protocol (contract-of hbtc-vault)))
          (try! (contract-call? hbtc-vault fund-claim-many claim-ids))
        )
        true)

      (print { action: "zest-close-remove", user: contract-caller, data: { market: market, staking: staking, staking-silo: staking-silo, hbtc-vault: hbtc-vault, collateral: { token: collateral-token, amount: collateral-amount }, unstake-amount: unstake-amount, repay: { token: repay-token, amount: repay-amount }, claim-ids: claim-ids } })
      (ok true)
    )
  )
)

;;=====================================
;; VAULT PATH (Collateral -> z-tokens)
;;=====================================

;;-------------------------------------
;; Open Position - Vault Path
;;-------------------------------------

;; @desc - Opens a leveraged position using vault path
(define-public (zest-deposit-add-open
  (market <zest-market>) (vault <zest-vault>) (staking <staking-trait>)
  (collateral-token <ft>) (borrow-token <ft>)
  (collateral-amount uint) (borrow-amount uint) (min-shares uint)
  (price-feed-1 (optional (buff 8192))) (price-feed-2 (optional (buff 8192))))
  (begin
    (try! (contract-call? .test-hq-vaults-v6 check-is-trader contract-caller))
    (asserts! (> collateral-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> borrow-amount u0) ERR_INVALID_AMOUNT)
    (let (
      ;; Step 1: Deposit collateral to vault and get z-tokens
      (z-tokens-received (try! (contract-call? .test-zest-interface-hbtc-v6-1 zest-deposit vault collateral-token collateral-amount min-shares))))
      
      ;; Step 1b: Add z-tokens as collateral to Zest market
      (try! (contract-call? .test-zest-interface-hbtc-v6-1 zest-collateral-add market vault z-tokens-received price-feed-1 price-feed-2))

      ;; Step 2: Borrow asset and stake it in Hermetica
      ;; Validate that borrow token is the canonical borrow token
      (asserts! (is-eq (contract-of borrow-token) usdh-token) ERR_INVALID_TOKEN)
      ;; Borrow asset from Zest v2 market
      (try! (contract-call? .test-zest-interface-hbtc-v6-1 zest-borrow market borrow-token borrow-amount none none))
      ;; Stake the borrowed asset into Hermetica
      (try! (contract-call? .test-hermetica-interface-hbtc-v6 hermetica-stake borrow-amount staking))

      (print { action: "zest-deposit-add-open", user: contract-caller, data: { market: market, vault: vault, staking: staking, collateral: { token: collateral-token, amount: collateral-amount }, borrow: { token: borrow-token, amount: borrow-amount } } })
      (ok true)
    )
  )
)

;;-------------------------------------
;; Close Position - Vault Paths
;;-------------------------------------

;; @desc - Closes a leveraged position using vault path
(define-public (zest-close-remove-redeem
  (market <zest-market>) (vault <zest-vault>) (staking <staking-trait>) (staking-silo <staking-silo-trait>) (hbtc-vault <hbtc-vault-trait>)
  (repay-token <ft>)
  (unstake-amount uint) (collateral-amount uint) (min-collateral-amount uint)
  (claim-ids (list 1000 uint))
  (price-feed-1 (optional (buff 8192))) (price-feed-2 (optional (buff 8192))))
  (begin
    (try! (contract-call? .test-hq-vaults-v6 check-is-trader contract-caller))
    (asserts! (> unstake-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> collateral-amount u0) ERR_INVALID_AMOUNT)

    ;; Step 1: Unstake and repay loan
    (let (
      ;; Unstake asset from Hermetica (instant withdrawal)
      (repay-amount (try! (contract-call? .test-hermetica-interface-hbtc-v6 hermetica-unstake-and-withdraw unstake-amount staking staking-silo))))
      ;; Validate that repay token is the canonical borrow token
      (asserts! (is-eq (contract-of repay-token) usdh-token) ERR_INVALID_TOKEN)
      ;; Repay loan to Zest v2 market
      (try! (contract-call? .test-zest-interface-hbtc-v6-1 zest-repay market repay-token repay-amount price-feed-1 price-feed-2))

      ;; Step 2: Remove z-token collateral
      (try! (contract-call? .test-zest-interface-hbtc-v6-1 zest-collateral-remove market vault collateral-amount none none))
      
      ;; Step 3: Redeem collateral from vault (burn z-tokens, get actual collateral amount)
      (try! (contract-call? .test-zest-interface-hbtc-v6-1 zest-redeem vault collateral-amount min-collateral-amount))
      
      ;; Step 4: Optional - Fund claims with collateral now in reserve
      (if (> (len claim-ids) u0)
        (begin
          (try! (contract-call? .test-hq-vaults-v6 check-is-protocol (contract-of hbtc-vault)))
          (try! (contract-call? hbtc-vault fund-claim-many claim-ids))
        )
        true)

      (print { action: "zest-close-remove-redeem", user: contract-caller, data: { market: market, vault: vault, staking: staking, staking-silo: staking-silo, hbtc-vault: hbtc-vault, collateral: { amount: collateral-amount, min-amount: min-collateral-amount }, unstake-amount: unstake-amount, repay: { token: repay-token, amount: repay-amount }, claim-ids: claim-ids } })
      (ok true)
    )
  )
)

```
