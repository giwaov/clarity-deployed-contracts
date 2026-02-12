;; @contract Trading v0.2
;; @version 0.2
;; @description Batched and atomic position management across DeFi protocols

(use-trait ft 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.ft-trait.ft-trait)
(use-trait zest-market 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.staging-market-trait-v0.market-trait)
(use-trait zest-vault 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.staging-vault-traits-v0.tokenized-vault)
(use-trait hbtc-vault-trait .test-vault-trait-v3.vault-trait)
(use-trait staking-trait 'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.staking-trait-v1.staking-trait)
(use-trait staking-silo-trait 'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.staking-silo-trait-v1.staking-silo-trait)

;;-------------------------------------
;; Constants
;;-------------------------------------

(define-constant ERR_INVALID_AMOUNT (err u120001))
(define-constant ERR_INVALID_TOKEN (err u120002))

(define-constant usdh-token 'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.usdh-token-v1)

;; @desc - Borrows asset from Zest v2 market and stakes it in Hermetica
;; @param - market: Zest v2 market contract
;; @param - staking: Hermetica staking contract
;; @param - borrow-token: Borrow token contract
;; @param - borrow-amount: Amount to borrow and stake
;; @param - price-feed-1: Pyth price feed data
;; @param - price-feed-2: Secondary price feed data
(define-public (zest-open
  (market <zest-market>) (staking <staking-trait>) 
  (borrow-token <ft>)
  (borrow-amount uint)
  (price-feed-1 (optional (buff 8192))) (price-feed-2 (optional (buff 8192))))
  (begin
    (try! (contract-call? .test-hq-vaults-v5 check-is-trader contract-caller))
    (asserts! (> borrow-amount u0) ERR_INVALID_AMOUNT)
    ;; Validate that borrow token is the canonical borrow token
    (asserts! (is-eq (contract-of borrow-token) usdh-token) ERR_INVALID_TOKEN)
    ;; Borrow asset from Zest v2 market
    (try! (contract-call? .test-zest-interface-hbtc-v5 zest-borrow market borrow-token borrow-amount price-feed-1 price-feed-2))
    ;; Stake the borrowed asset into Hermetica
    (try! (contract-call? .test-hermetica-interface-hbtc-v5-1 hermetica-stake borrow-amount staking))
    (print { action: "zest-open", user: contract-caller, data: { borrow: { token: borrow-token, amount: borrow-amount } } })
    (ok true)
  )
)

;; @desc - Unstakes asset from Hermetica and repays loan to Zest v2 market
;; @param - market: Zest v2 market contract
;; @param - staking: Hermetica staking contract
;; @param - staking-silo: Hermetica silo for withdrawal claims
;; @param - repay-token: Repay token contract
;; @param - staked-amount: Amount to unstake
;; @param - price-feed-1: Pyth price feed data
;; @param - price-feed-2: Secondary price feed data
(define-public (zest-close
  (market <zest-market>) (staking <staking-trait>) (staking-silo <staking-silo-trait>) 
  (repay-token <ft>)
  (staked-amount uint)
  (price-feed-1 (optional (buff 8192))) (price-feed-2 (optional (buff 8192))))
  (begin
    (try! (contract-call? .test-hq-vaults-v5 check-is-trader contract-caller))
    (asserts! (> staked-amount u0) ERR_INVALID_AMOUNT)
    (let (
      ;; Unstake asset from Hermetica (instant withdrawal)
      (repay-amount (try! (contract-call? .test-hermetica-interface-hbtc-v5-1 hermetica-unstake-and-withdraw staked-amount staking staking-silo))))
      ;; Validate that repay token is the canonical borrow token
      (asserts! (is-eq (contract-of repay-token) usdh-token) ERR_INVALID_TOKEN)
      ;; Repay loan to Zest v2 market
      (try! (contract-call? .test-zest-interface-hbtc-v5 zest-repay market repay-token repay-amount price-feed-1 price-feed-2))

      (print { action: "zest-close", user: contract-caller, data: { staked-amount: staked-amount, repay: { token: repay-token, amount: repay-amount } } })
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
;; @note - Uses asset directly as collateral in Zest market (no vault intermediary)
;; @param - market: Zest v2 market contract
;; @param - staking: Hermetica staking contract
;; @param - collateral-token: Collateral token contract
;; @param - borrow-token: Borrow token contract
;; @param - collateral-amount: Amount of collateral to deposit
;; @param - borrow-amount: Amount to borrow and stake
;; @param - price-feed-1: Pyth price feed data for collateral
;; @param - price-feed-2: Secondary price feed data
(define-public (zest-add-open
  (market <zest-market>) (staking <staking-trait>) (collateral-token <ft>) (borrow-token <ft>)
  (collateral-amount uint) (borrow-amount uint)
  (price-feed-1 (optional (buff 8192))) (price-feed-2 (optional (buff 8192))))
  (begin
    (try! (contract-call? .test-hq-vaults-v5 check-is-trader contract-caller))
    (asserts! (> collateral-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> borrow-amount u0) ERR_INVALID_AMOUNT)

    ;; Step 1: Add collateral directly
    (try! (contract-call? .test-zest-interface-hbtc-v5 zest-collateral-add market collateral-token collateral-amount none))

    ;; Validate that borrow token is the canonical borrow token
    (asserts! (is-eq (contract-of borrow-token) usdh-token) ERR_INVALID_TOKEN)
    ;; Borrow asset from Zest v2 market
    (try! (contract-call? .test-zest-interface-hbtc-v5 zest-borrow market borrow-token borrow-amount price-feed-1 price-feed-2))
    ;; Stake the borrowed asset into Hermetica
    (try! (contract-call? .test-hermetica-interface-hbtc-v5-1 hermetica-stake borrow-amount staking))

    (print { action: "zest-add-open", user: contract-caller, data: { collateral: { token: collateral-token, amount: collateral-amount }, borrow: { token: borrow-token, amount: borrow-amount } } })
    (ok true)
  )
)

;;-------------------------------------
;; Close Position - Direct Path
;;-------------------------------------

;; @desc - Closes a leveraged position using direct collateral
;; @note - Removes collateral directly from Zest market (no vault intermediary)
;; @param - market: Zest v2 market contract
;; @param - staking: Hermetica staking contract
;; @param - staking-silo: Hermetica silo for withdrawal claims
;; @param - hbtc-vault: Vault for collateral claims
;; @param - collateral-token: Collateral token contract
;; @param - repay-token: Repay token contract
;; @param - staked-amount: Amount to unstake from Hermetica
;; @param - collateral-amount: Amount of collateral to remove
;; @param - claim-ids: List of claim IDs to fund with collateral (optional, can be empty)
;; @param - price-feed-1: Pyth price feed data for collateral
;; @param - price-feed-2: Secondary price feed data
(define-public (zest-close-remove
  (market <zest-market>) (staking <staking-trait>) (staking-silo <staking-silo-trait>) (hbtc-vault <hbtc-vault-trait>)
  (collateral-token <ft>) (repay-token <ft>)
  (unstake-amount uint) (collateral-amount uint)
  (claim-ids (list 1000 uint))
  (price-feed-1 (optional (buff 8192))) (price-feed-2 (optional (buff 8192))))
  (begin
    (try! (contract-call? .test-hq-vaults-v5 check-is-trader contract-caller))
    (asserts! (> unstake-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> collateral-amount u0) ERR_INVALID_AMOUNT)

    ;; Step 1: Unstake and repay loan
    (let (
      ;; Unstake asset from Hermetica (instant withdrawal)
      (repay-amount (try! (contract-call? .test-hermetica-interface-hbtc-v5-1 hermetica-unstake-and-withdraw unstake-amount staking staking-silo))))

      ;; Validate that repay token is the canonical borrow token
      (asserts! (is-eq (contract-of repay-token) usdh-token) ERR_INVALID_TOKEN)
      ;; Repay loan to Zest v2 market
      (try! (contract-call? .test-zest-interface-hbtc-v5 zest-repay market repay-token repay-amount price-feed-1 price-feed-2))

      ;; Step 2: Remove collateral
      (try! (contract-call? .test-zest-interface-hbtc-v5 zest-collateral-remove market collateral-token collateral-amount none none))
      
      ;; Step 3: Optional - Fund claims with collateral now in reserve
      (if (> (len claim-ids) u0)
        (begin
          (try! (contract-call? .test-hq-vaults-v5 check-is-protocol (contract-of hbtc-vault)))
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
;; @note - Deposits collateral to vault, receives z-tokens, uses z-tokens as collateral
;; @param - market: Zest v2 market contract
;; @param - vault: Zest v2 tokenized vault
;; @param - staking: Hermetica staking contract
;; @param - collateral-token: Collateral token contract
;; @param - borrow-token: Borrow token contract
;; @param - collateral-amount: Amount of collateral to supply to vault
;; @param - borrow-amount: Amount to borrow and stake
;; @param - min-shares: Minimum vault shares to receive
;; @param - price-feed-1: Pyth price feed data for collateral
;; @param - price-feed-2: Secondary price feed data
(define-public (zest-deposit-add-open
  (market <zest-market>) (vault <zest-vault>) (staking <staking-trait>)
  (collateral-token <ft>) (borrow-token <ft>)
  (collateral-amount uint) (borrow-amount uint) (min-shares uint)
  (price-feed-1 (optional (buff 8192))) (price-feed-2 (optional (buff 8192))))
  (begin
    (try! (contract-call? .test-hq-vaults-v5 check-is-trader contract-caller))
    (asserts! (> collateral-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> borrow-amount u0) ERR_INVALID_AMOUNT)
    (let (
      ;; Step 1: Deposit collateral to vault and get z-tokens
      (z-tokens-received (try! (contract-call? .test-zest-interface-hbtc-v5 zest-deposit vault collateral-token collateral-amount min-shares))))
      
      ;; Step 1b: Add z-tokens as collateral to Zest market
      (try! (contract-call? .test-zest-interface-hbtc-v5 zest-collateral-add market vault z-tokens-received none))

      ;; Validate that borrow token is the canonical borrow token
      (asserts! (is-eq (contract-of borrow-token) usdh-token) ERR_INVALID_TOKEN)
      ;; Borrow asset from Zest v2 market
      (try! (contract-call? .test-zest-interface-hbtc-v5 zest-borrow market borrow-token borrow-amount price-feed-1 price-feed-2))
      ;; Stake the borrowed asset into Hermetica
      (try! (contract-call? .test-hermetica-interface-hbtc-v5-1 hermetica-stake borrow-amount staking))

      (print { action: "zest-deposit-add-open", user: contract-caller, data: { collateral: { token: collateral-token, amount: collateral-amount }, borrow: { token: borrow-token, amount: borrow-amount } } })
      (ok true)
    )
  )
)

;;-------------------------------------
;; Close Position - Vault Paths
;;-------------------------------------

;; @desc - Closes a leveraged position using vault path
;; @note - Removes z-tokens from collateral, redeems them for collateral from vault
;; @param - market: Zest v2 market contract
;; @param - vault: Zest v2 tokenized vault
;; @param - staking: Hermetica staking contract
;; @param - staking-silo: Hermetica silo for withdrawal claims
;; @param - hbtc-vault: Vault for collateral claims
;; @param - repay-token: Repay token contract
;; @param - staked-amount: Amount to unstake from Hermetica
;; @param - collateral-amount: Amount of z-token collateral to remove
;; @param - min-collateral-amount: Minimum collateral to receive from vault withdrawal
;; @param - claim-ids: List of claim IDs to fund with collateral after all operations complete
;; @param - price-feed-1: Pyth price feed data for collateral
;; @param - price-feed-2: Secondary price feed data
(define-public (zest-close-remove-redeem
  (market <zest-market>) (vault <zest-vault>) (staking <staking-trait>) (staking-silo <staking-silo-trait>) (hbtc-vault <hbtc-vault-trait>)
  (repay-token <ft>)
  (unstake-amount uint) (collateral-amount uint) (min-collateral-amount uint)
  (claim-ids (list 1000 uint))
  (price-feed-1 (optional (buff 8192))) (price-feed-2 (optional (buff 8192))))
  (begin
    (try! (contract-call? .test-hq-vaults-v5 check-is-trader contract-caller))
    (asserts! (> unstake-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> collateral-amount u0) ERR_INVALID_AMOUNT)

    ;; Step 1: Unstake and repay loan
    (let (
      ;; Unstake asset from Hermetica (instant withdrawal)
      (repay-amount (try! (contract-call? .test-hermetica-interface-hbtc-v5-1 hermetica-unstake-and-withdraw unstake-amount staking staking-silo))))
      ;; Validate that repay token is the canonical borrow token
      (asserts! (is-eq (contract-of repay-token) usdh-token) ERR_INVALID_TOKEN)
      ;; Repay loan to Zest v2 market
      (try! (contract-call? .test-zest-interface-hbtc-v5 zest-repay market repay-token repay-amount price-feed-1 price-feed-2))

      ;; Step 2: Remove z-token collateral
      (try! (contract-call? .test-zest-interface-hbtc-v5 zest-collateral-remove market vault collateral-amount none none))
      
      ;; Step 3: Redeem collateral from vault (burn z-tokens, get actual collateral amount)
      (try! (contract-call? .test-zest-interface-hbtc-v5 zest-redeem vault collateral-amount min-collateral-amount))
      
      ;; Step 4: Optional - Fund claims with collateral now in reserve
      (if (> (len claim-ids) u0)
        (begin
          (try! (contract-call? .test-hq-vaults-v5 check-is-protocol (contract-of hbtc-vault)))
          (try! (contract-call? hbtc-vault fund-claim-many claim-ids))
        )
        true)

      (print { action: "zest-close-remove-redeem", user: contract-caller, data: { market: market, vault: vault, staking: staking, staking-silo: staking-silo, hbtc-vault: hbtc-vault, collateral: { amount: collateral-amount, min-amount: min-collateral-amount }, unstake-amount: unstake-amount, repay: { token: repay-token, amount: repay-amount }, claim-ids: claim-ids } })
      (ok true)
    )
  )
)
