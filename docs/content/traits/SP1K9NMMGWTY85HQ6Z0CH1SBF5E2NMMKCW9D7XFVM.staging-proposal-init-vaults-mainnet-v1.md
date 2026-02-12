---
title: "Trait staging-proposal-init-vaults-mainnet-v1"
draft: true
---
```
;; Mainnet Proposal: Initialize Vaults
;; This proposal initializes all vaults with production caps,
;; mints minimum liquidity, and authorizes the market contract

(impl-trait .staging-dao-traits-v0.proposal-script)

;; =========================================================================
;; VAULT CAPS CONFIGURATION
;; =========================================================================
;; Initial conservative caps - can be increased via subsequent proposals
;; All values are in base units (scaled by token decimals)

;; STX vault caps (6 decimals): 10M STX
(define-constant CAP-STX-SUPPLY u10000000000000)
(define-constant CAP-STX-DEBT u10000000000000)

;; sBTC vault caps (8 decimals): 100 BTC
(define-constant CAP-SBTC-SUPPLY u10000000000)
(define-constant CAP-SBTC-DEBT u10000000000)

;; stSTX vault caps (6 decimals): 10M stSTX
(define-constant CAP-STSTX-SUPPLY u10000000000000)
(define-constant CAP-STSTX-DEBT u10000000000000)

;; USDC vault caps (6 decimals): 10M USDC
(define-constant CAP-USDC-SUPPLY u10000000000000)
(define-constant CAP-USDC-DEBT u10000000000000)

;; USDh vault caps (8 decimals): 10M USDh
(define-constant CAP-USDH-SUPPLY u1000000000000000)
(define-constant CAP-USDH-DEBT u1000000000000000)

(define-public (execute)
  (begin
    ;; =========================================================================
    ;; STEP 1: SET VAULT CAPS
    ;; Must be set before initialization to prevent unlimited deposits
    ;; =========================================================================
    
    ;; STX vault caps
    (try! (contract-call? .staging-vault-stx-v0 set-cap-supply CAP-STX-SUPPLY))
    (try! (contract-call? .staging-vault-stx-v0 set-cap-debt CAP-STX-DEBT))
    
    ;; sBTC vault caps
    (try! (contract-call? .staging-vault-sbtc-v0 set-cap-supply CAP-SBTC-SUPPLY))
    (try! (contract-call? .staging-vault-sbtc-v0 set-cap-debt CAP-SBTC-DEBT))
    
    ;; stSTX vault caps
    (try! (contract-call? .staging-vault-ststx-v0 set-cap-supply CAP-STSTX-SUPPLY))
    (try! (contract-call? .staging-vault-ststx-v0 set-cap-debt CAP-STSTX-DEBT))
    
    ;; USDC vault caps
    (try! (contract-call? .staging-vault-usdc-v0 set-cap-supply CAP-USDC-SUPPLY))
    (try! (contract-call? .staging-vault-usdc-v0 set-cap-debt CAP-USDC-DEBT))
    
    ;; USDh vault caps
    (try! (contract-call? .staging-vault-usdh-v0 set-cap-supply CAP-USDH-SUPPLY))
    (try! (contract-call? .staging-vault-usdh-v0 set-cap-debt CAP-USDH-DEBT))
    
    ;; =========================================================================
    ;; STEP 2: AUTHORIZE MARKET CONTRACT
    ;; Allows market to call deposit, redeem, borrow, repay on vaults
    ;; =========================================================================
    
    (try! (contract-call? .staging-vault-stx-v0 set-authorized-contract .staging-market-v0 true))
    (try! (contract-call? .staging-vault-sbtc-v0 set-authorized-contract .staging-market-v0 true))
    (try! (contract-call? .staging-vault-ststx-v0 set-authorized-contract .staging-market-v0 true))
    (try! (contract-call? .staging-vault-usdc-v0 set-authorized-contract .staging-market-v0 true))
    (try! (contract-call? .staging-vault-usdh-v0 set-authorized-contract .staging-market-v0 true))
    
    (ok true)))

```
