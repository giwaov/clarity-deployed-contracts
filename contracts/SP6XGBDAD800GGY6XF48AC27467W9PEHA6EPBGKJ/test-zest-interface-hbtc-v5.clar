;; @contract Zest Interface v2
;; @version 0.2
;; @desc Interface for Zest v2 lending protocol integration

(use-trait ft 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.ft-trait.ft-trait)
(use-trait zest-market 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.staging-market-trait-v0.market-trait)
(use-trait zest-vault 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.staging-vault-traits-v0.tokenized-vault)

(define-constant ERR_INVALID_AMOUNT (err u111001))
(define-constant ERR_INSUFFICIENT_BALANCE (err u111002))

(define-constant reserve .test-reserve-hbtc-v5)

;;-------------------------------------
;; Trader - Collateral Management
;;-------------------------------------

;; @desc - Adds collateral to Zest v2 market
;; @param - market: Zest v2 market contract
;; @param - asset: Token to supply as collateral
;; @param - amount: Amount of tokens to supply
;; @param - price-feeds: Optional list of up to 3 Pyth price feed buffers to update stale prices
;; @returns - New total collateral amount for this asset
(define-public (zest-collateral-add
  (market <zest-market>)
  (asset <ft>)
  (amount uint)
  (price-feeds (optional (list 3 (buff 8192)))))
  (begin
    (try! (contract-call? .test-hq-vaults-v5 check-is-trader contract-caller))
    (try! (contract-call? .test-state-hbtc-v5 check-trading-auth (contract-of market) none (some (contract-of asset)) none))
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)

    ;; Transfer tokens from reserve to this interface
    (try! (contract-call? .test-reserve-hbtc-v5 transfer asset amount current-contract))
    
    ;; Add collateral to Zest market (position owned by this interface contract)
    (let ((total (try! (as-contract? ((with-all-assets-unsafe)) (try! (contract-call? market collateral-add asset amount price-feeds))))))
      (print { action: "zest-collateral-add", user: contract-caller, data: { market: market, asset: asset, amount: amount, total: total } })
      (ok total)
    )
  )
)

;; @desc - Removes collateral from Zest v2 market
;; @param - market: Zest v2 market contract
;; @param - asset: Token to remove from collateral
;; @param - amount: Amount of tokens to remove
;; @param - price-feed-1: Optional Pyth price feed data for sBTC
;; @param - price-feed-2: Optional Pyth price feed data (secondary)
;; @returns - Remaining collateral amount for this asset
(define-public (zest-collateral-remove
  (market <zest-market>)
  (asset <ft>)
  (amount uint)
  (price-feed-1 (optional (buff 8192)))
  (price-feed-2 (optional (buff 8192))))
  (begin
    (try! (contract-call? .test-hq-vaults-v5 check-is-trader contract-caller))
    (try! (contract-call? .test-state-hbtc-v5 check-trading-auth (contract-of market) none (some (contract-of asset)) none))
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Update Pyth price feed for sBTC before operation (DIA handles USDh)
    (try! (write-feed price-feed-1))
    (try! (write-feed price-feed-2))
    
    ;; Remove collateral from Zest market and capture remaining amount
    (let ((remaining (try! (as-contract? ((with-all-assets-unsafe)) (try! (contract-call? market collateral-remove asset amount (some current-contract) none))))))
      ;; Transfer tokens back to reserve
      (try! (as-contract? ((with-all-assets-unsafe)) (try! (contract-call? asset transfer amount current-contract reserve none))))
      
      (print { action: "zest-collateral-remove", user: contract-caller, data: { market: market, asset: asset, amount: amount, remaining: remaining } })
      (ok remaining)
    )
  )
)

;;-------------------------------------
;; Trader - Borrowing
;;-------------------------------------

;; @desc - Borrows assets from Zest v2 market
;; @param - market: Zest v2 market contract
;; @param - asset: Token to borrow
;; @param - amount: Amount of tokens to borrow
;; @param - price-feed-1: Optional Pyth price feed data for sBTC
;; @param - price-feed-2: Optional Pyth price feed data (secondary)
(define-public (zest-borrow
  (market <zest-market>)
  (asset <ft>)
  (amount uint)
  (price-feed-1 (optional (buff 8192)))
  (price-feed-2 (optional (buff 8192))))
  (begin
    (try! (contract-call? .test-hq-vaults-v5 check-is-trader contract-caller))
    (try! (contract-call? .test-state-hbtc-v5 check-trading-auth (contract-of market) none (some (contract-of asset)) none))
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Update Pyth price feed for sBTC before operation (DIA handles USDh)
    (try! (write-feed price-feed-1))
    (try! (write-feed price-feed-2))
    
    ;; Borrow from Zest market (debt recorded under this interface contract)
    (try! (as-contract? ((with-all-assets-unsafe)) (try! (contract-call? market borrow asset amount (some current-contract) none))))
    
    ;; Transfer borrowed tokens to reserve
    (try! (as-contract? ((with-all-assets-unsafe)) (try! (contract-call? asset transfer amount current-contract reserve none))))
    
    (print { action: "zest-borrow", user: contract-caller, data: { market: market, asset: asset, amount: amount } })
    (ok true)
  )
)

;; @desc - Repays borrowed assets to Zest v2 market
;; @param - market: Zest v2 market contract
;; @param - asset: Token to repay
;; @param - amount: Amount of tokens to repay
;; @param - price-feed-1: Optional Pyth price feed data for sBTC
;; @param - price-feed-2: Optional Pyth price feed data (secondary)
(define-public (zest-repay
  (market <zest-market>)
  (asset <ft>)
  (amount uint)
  (price-feed-1 (optional (buff 8192)))
  (price-feed-2 (optional (buff 8192))))
  (begin
    (try! (contract-call? .test-hq-vaults-v5 check-is-trader contract-caller))
    (try! (contract-call? .test-state-hbtc-v5 check-trading-auth (contract-of market) none (some (contract-of asset)) none))
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Update Pyth price feed for sBTC before operation (DIA handles USDh)
    (try! (write-feed price-feed-1))
    (try! (write-feed price-feed-2))
    
    ;; Transfer repayment from reserve to this interface
    (try! (contract-call? .test-reserve-hbtc-v5 transfer asset amount current-contract))
    
    (let ((repaid-amount (try! (as-contract? ((with-all-assets-unsafe)) (try! (contract-call? market repay asset amount (some current-contract)))))))
      (print { action: "zest-repay", user: contract-caller, data: { market: market, asset: asset, amount: amount, repaid-amount: repaid-amount } })
      (ok repaid-amount)
    )
  )
)

;;-------------------------------------
;; Liquidity Provider - Vault Management
;;-------------------------------------

;; @desc - Deposits assets to Zest v2 vault as liquidity provider
;; @param - vault: Zest v2 tokenized vault
;; @param - asset: Token to deposit to vault
;; @param - amount: Amount of tokens to deposit
;; @param - min-shares: Minimum vault shares to receive (slippage protection)
(define-public (zest-deposit
  (vault <zest-vault>)
  (asset <ft>)
  (amount uint)
  (min-shares uint))
  (begin
    (try! (contract-call? .test-hq-vaults-v5 check-is-trader contract-caller))
    (try! (contract-call? .test-state-hbtc-v5 check-trading-auth (contract-of vault) none (some (contract-of asset)) none))
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Transfer asset from reserve to this interface
    (try! (contract-call? .test-reserve-hbtc-v5 transfer asset amount current-contract))
    
    ;; Deposit to Zest vault (z-tokens minted directly to reserve)
    (let (
      (received (try! (as-contract? ((with-all-assets-unsafe)) (try! (contract-call? vault deposit amount min-shares reserve)))))
    )
      (print { action: "zest-deposit", user: contract-caller, data: { vault: vault, asset: asset, amount: amount, min-shares: min-shares, shares: received } })
      (ok received)
    )
  )
)

;; @desc - Redeems vault shares from Zest v2 vault
;; @param - vault: Zest v2 tokenized vault
;; @param - shares: Amount of vault shares to redeem
;; @param - min-amount: Minimum underlying tokens to receive (slippage protection)
(define-public (zest-redeem
  (vault <zest-vault>)
  (shares uint)
  (min-amount uint))
  (begin
    (try! (contract-call? .test-hq-vaults-v5 check-is-trader contract-caller))
    (try! (contract-call? .test-state-hbtc-v5 check-trading-auth (contract-of vault) none none none))
    (asserts! (> shares u0) ERR_INVALID_AMOUNT)

    ;; Transfer z-tokens from reserve to this interface
    (try! (contract-call? .test-reserve-hbtc-v5 transfer vault shares current-contract))

    (let (
      ;; Redeem from Zest vault (burns vault shares (z-tokens), receives underlying tokens)
      (received (try! (as-contract? ((with-all-assets-unsafe)) (try! (contract-call? vault redeem shares min-amount reserve)))))
    )
      (print { action: "zest-redeem", user: contract-caller, data: { vault: vault, shares: shares, collateral: { min-amount: min-amount, received: received } } })
      (ok received)
    )
  )
)

;;-------------------------------------
;; Admin
;;-------------------------------------

;; @desc - sweeps any leftover tokens from interface contract to reserve
;; @param - asset: the token to sweep
;; @param - amount: the amount to sweep
(define-public (sweep (asset <ft>) (amount uint))
  (begin
    (try! (contract-call? .test-hq-vaults-v5 check-is-trader contract-caller))
    (try! (contract-call? .test-state-hbtc-v5 check-is-asset (contract-of asset)))
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= amount (unwrap-panic (contract-call? asset get-balance current-contract))) ERR_INSUFFICIENT_BALANCE)
    (try! (as-contract? ((with-all-assets-unsafe)) (try! (contract-call? asset transfer amount current-contract reserve none))))
    (print { action: "sweep", user: contract-caller, data: { asset: asset, amount: amount, sender: current-contract, recipient: reserve } })
    (ok amount)
  )
)

;;-------------------------------------
;; Helper
;;-------------------------------------

(define-private (write-feed (price-feed (optional (buff 8192))))
  (match price-feed bytes 
    (begin
      (try! (contract-call? 'SP1CGXWEAMG6P6FT04W66NVGJ7PQWMDAC19R7PJ0Y.pyth-oracle-v4 verify-and-update-price-feeds
        bytes
        {
          pyth-storage-contract: 'SP1CGXWEAMG6P6FT04W66NVGJ7PQWMDAC19R7PJ0Y.pyth-storage-v4,
          pyth-decoder-contract: 'SP1CGXWEAMG6P6FT04W66NVGJ7PQWMDAC19R7PJ0Y.pyth-pnau-decoder-v3,
          wormhole-core-contract: 'SP1CGXWEAMG6P6FT04W66NVGJ7PQWMDAC19R7PJ0Y.wormhole-core-v4,
        }
      ))
      (print { action: "write-feed", user: contract-caller, data: { requested-by: current-contract, oracle: 'SP1CGXWEAMG6P6FT04W66NVGJ7PQWMDAC19R7PJ0Y.pyth-oracle-v4 } })
      (ok true)
    )
    ;; do nothing if none
    (ok true)
  )
)