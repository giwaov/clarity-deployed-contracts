---
title: "Trait vaults"
draft: true
---
```
;; ============================================================================
;; VAULTS.CLAR - Vault Lifecycle Management
;; ============================================================================
;; Core vault contract for the Bitcoin-backed stablecoin system.
;; Manages collateral deposits, stablecoin minting, repayment, and withdrawals.
;; Integrates with Chainhook relayer for BTC deposit crediting.
;; ============================================================================

;; ============================================================================
;; CONSTANTS
;; ============================================================================

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u5000))
(define-constant ERR-VAULT-NOT-FOUND (err u5001))
(define-constant ERR-VAULT-ALREADY-EXISTS (err u5002))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u5003))
(define-constant ERR-BELOW-MIN-COLLATERAL-RATIO (err u5004))
(define-constant ERR-VAULT-NOT-EMPTY (err u5005))
(define-constant ERR-INVALID-AMOUNT (err u5006))
(define-constant ERR-SYSTEM-PAUSED (err u5007))
(define-constant ERR-ORACLE-STALE (err u5008))
(define-constant ERR-VAULT-LIQUIDATABLE (err u5009))
(define-constant ERR-TX-ALREADY-PROCESSED (err u5010))
(define-constant ERR-VAULT-NOT-OWNER (err u5011))
(define-constant ERR-MINT-EXCEEDS-CAPACITY (err u5012))
(define-constant ERR-REPAY-EXCEEDS-DEBT (err u5013))
(define-constant ERR-WITHDRAW-EXCEEDS-AVAILABLE (err u5014))
(define-constant ERR-VAULT-HAS-DEBT (err u5015))

;; Precision constants
(define-constant PRICE-SCALE u100000000)            ;; 1e8 for price
(define-constant COLLATERAL-SCALE u100000000)       ;; 1e8 for BTC (satoshis)
(define-constant STABLECOIN-SCALE u1000000)         ;; 1e6 for stablecoin
(define-constant BPS u10000)                         ;; Basis points scale

;; Default vault parameters
(define-constant DEFAULT-MIN-COLLATERAL-RATIO u15000)   ;; 150% (in BPS)
(define-constant DEFAULT-LIQUIDATION-RATIO u13000)      ;; 130% (in BPS)
(define-constant MIN-DEBT-AMOUNT u1000000)              ;; Minimum 1 BTCD debt

;; ============================================================================
;; DATA STORAGE
;; ============================================================================

;; Vault counter for generating IDs
(define-data-var vault-counter uint u0)

;; Vault data structure
(define-map vaults
  uint  ;; vault-id
  {
    owner: principal,
    collateral: uint,          ;; BTC collateral in satoshis (1e8)
    debt: uint,                ;; Stablecoin debt (1e6)
    created-at: uint,          ;; Block height when created
    last-updated: uint,        ;; Block height when last modified
    status: (string-ascii 10)  ;; "active", "closed", "liquidated"
  })

;; Map user to their vault IDs
(define-map user-vaults principal (list 100 uint))

;; Processed BTC transactions to prevent replay
;; Maps btc-txid:vout -> true
(define-map processed-btc-txs (buff 36) bool)

;; System parameters
(define-data-var min-collateral-ratio uint DEFAULT-MIN-COLLATERAL-RATIO)
(define-data-var liquidation-ratio uint DEFAULT-LIQUIDATION-RATIO)

;; Global state
(define-data-var total-collateral uint u0)
(define-data-var total-debt uint u0)

;; Contract references
(define-data-var oracle-contract principal tx-sender)
(define-data-var stablecoin-contract principal tx-sender)
(define-data-var fees-contract principal tx-sender)
(define-data-var liquidation-contract principal tx-sender)
(define-data-var access-contract principal tx-sender)

;; Relayer address (set by admin)
(define-data-var chainhook-relayer principal tx-sender)

;; System pause
(define-data-var paused bool false)

;; Admin
(define-data-var contract-admin principal tx-sender)

;; ============================================================================
;; VAULT LIFECYCLE FUNCTIONS
;; ============================================================================

;; Open a new vault
;; Returns the new vault ID
(define-public (open-vault)
  (let (
    (vault-id (+ (var-get vault-counter) u1))
    (existing-vaults (default-to (list) (map-get? user-vaults tx-sender)))
  )
    ;; Check not paused
    (asserts! (not (var-get paused)) ERR-SYSTEM-PAUSED)
    
    ;; Create the vault
    (map-set vaults vault-id {
      owner: tx-sender,
      collateral: u0,
      debt: u0,
      created-at: block-height,
      last-updated: block-height,
      status: "active"
    })
    
    ;; Update user's vault list
    (map-set user-vaults tx-sender (unwrap! (as-max-len? (append existing-vaults vault-id) u100) (err u5020)))
    
    ;; Increment counter
    (var-set vault-counter vault-id)
    
    ;; Initialize fee state for this vault (would call fees contract)
    ;; (try! (contract-call? .fees init-vault-fee-state vault-id))
    
    (print {
      event: "vault-opened",
      vault-id: vault-id,
      owner: tx-sender,
      block: block-height
    })
    
    (ok vault-id)))

;; Deposit collateral to a vault (for wrapped BTC already on Stacks)
;; This is for users who already have xBTC/sBTC tokens
(define-public (deposit-collateral (vault-id uint) (amount uint))
  (let (
    (vault (unwrap! (map-get? vaults vault-id) ERR-VAULT-NOT-FOUND))
  )
    ;; Check ownership
    (asserts! (is-eq tx-sender (get owner vault)) ERR-VAULT-NOT-OWNER)
    
    ;; Check not paused
    (asserts! (not (var-get paused)) ERR-SYSTEM-PAUSED)
    
    ;; Check vault is active
    (asserts! (is-eq (get status vault) "active") ERR-VAULT-NOT-FOUND)
    
    ;; Check valid amount
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    ;; Transfer wrapped BTC from user to this contract
    ;; (try! (contract-call? .wrapped-btc transfer amount tx-sender (as-contract tx-sender) none))
    
    ;; Update vault
    (map-set vaults vault-id (merge vault {
      collateral: (+ (get collateral vault) amount),
      last-updated: block-height
    }))
    
    ;; Update global state
    (var-set total-collateral (+ (var-get total-collateral) amount))
    
    (print {
      event: "collateral-deposited",
      vault-id: vault-id,
      amount: amount,
      new-collateral: (+ (get collateral vault) amount),
      depositor: tx-sender
    })
    
    (ok true)))

;; Credit collateral from Chainhook (relayer only)
;; Called when BTC deposit is confirmed on Bitcoin mainnet
;; @param user: The user's Stacks address (from OP_RETURN or mapping)
;; @param amount: BTC amount in satoshis
;; @param btc-txid: Bitcoin transaction ID + vout for replay protection
(define-public (credit-collateral (user principal) (vault-id uint) (amount uint) (btc-txid (buff 36)))
  (let (
    (vault (unwrap! (map-get? vaults vault-id) ERR-VAULT-NOT-FOUND))
  )
    ;; Only relayer can call this
    (asserts! (is-eq tx-sender (var-get chainhook-relayer)) ERR-NOT-AUTHORIZED)
    
    ;; Check not paused
    (asserts! (not (var-get paused)) ERR-SYSTEM-PAUSED)
    
    ;; Check vault ownership matches user
    (asserts! (is-eq user (get owner vault)) ERR-VAULT-NOT-OWNER)
    
    ;; Check vault is active
    (asserts! (is-eq (get status vault) "active") ERR-VAULT-NOT-FOUND)
    
    ;; Check for replay (tx already processed)
    (asserts! (is-none (map-get? processed-btc-txs btc-txid)) ERR-TX-ALREADY-PROCESSED)
    
    ;; Check valid amount
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    ;; Mark tx as processed
    (map-set processed-btc-txs btc-txid true)
    
    ;; Update vault collateral
    (map-set vaults vault-id (merge vault {
      collateral: (+ (get collateral vault) amount),
      last-updated: block-height
    }))
    
    ;; Update global state
    (var-set total-collateral (+ (var-get total-collateral) amount))
    
    (print {
      event: "collateral-credited",
      vault-id: vault-id,
      user: user,
      amount: amount,
      btc-txid: btc-txid,
      new-collateral: (+ (get collateral vault) amount),
      block: block-height
    })
    
    (ok true)))

;; Mint stablecoins against collateral
(define-public (mint (vault-id uint) (stable-amount uint))
  (let (
    (vault (unwrap! (map-get? vaults vault-id) ERR-VAULT-NOT-FOUND))
    (current-collateral (get collateral vault))
    (current-debt (get debt vault))
    (new-debt (+ current-debt stable-amount))
    (btc-price (unwrap! (get-btc-price) ERR-ORACLE-STALE))
  )
    ;; Check ownership
    (asserts! (is-eq tx-sender (get owner vault)) ERR-VAULT-NOT-OWNER)
    
    ;; Check not paused
    (asserts! (not (var-get paused)) ERR-SYSTEM-PAUSED)
    
    ;; Check vault is active
    (asserts! (is-eq (get status vault) "active") ERR-VAULT-NOT-FOUND)
    
    ;; Check valid amount
    (asserts! (> stable-amount u0) ERR-INVALID-AMOUNT)
    
    ;; Check minimum debt amount
    (asserts! (>= new-debt MIN-DEBT-AMOUNT) ERR-INVALID-AMOUNT)
    
    ;; Calculate and check collateral ratio
    (let (
      (collateral-value-usd (calculate-collateral-value current-collateral btc-price))
      (new-collateral-ratio (calculate-ratio collateral-value-usd new-debt))
    )
      ;; Must maintain minimum collateral ratio
      (asserts! (>= new-collateral-ratio (var-get min-collateral-ratio)) ERR-BELOW-MIN-COLLATERAL-RATIO)
      
      ;; Update vault
      (map-set vaults vault-id (merge vault {
        debt: new-debt,
        last-updated: block-height
      }))
      
      ;; Update global state
      (var-set total-debt (+ (var-get total-debt) stable-amount))
      
      ;; Mint stablecoins to user
      ;; (try! (contract-call? .stablecoin mint stable-amount tx-sender))
      
      (print {
        event: "stablecoin-minted",
        vault-id: vault-id,
        amount: stable-amount,
        new-debt: new-debt,
        collateral-ratio: new-collateral-ratio,
        btc-price: btc-price,
        owner: tx-sender
      })
      
      (ok stable-amount))))

;; Repay stablecoin debt
(define-public (repay (vault-id uint) (stable-amount uint))
  (let (
    (vault (unwrap! (map-get? vaults vault-id) ERR-VAULT-NOT-FOUND))
    (current-debt (get debt vault))
  )
    ;; Check ownership
    (asserts! (is-eq tx-sender (get owner vault)) ERR-VAULT-NOT-OWNER)
    
    ;; Check not paused
    (asserts! (not (var-get paused)) ERR-SYSTEM-PAUSED)
    
    ;; Check vault is active
    (asserts! (is-eq (get status vault) "active") ERR-VAULT-NOT-FOUND)
    
    ;; Check valid amount
    (asserts! (> stable-amount u0) ERR-INVALID-AMOUNT)
    
    ;; Check doesn't exceed debt
    (asserts! (<= stable-amount current-debt) ERR-REPAY-EXCEEDS-DEBT)
    
    (let (
      (new-debt (- current-debt stable-amount))
    )
      ;; If partial repay, check minimum debt is maintained
      (asserts! (or (is-eq new-debt u0) (>= new-debt MIN-DEBT-AMOUNT)) ERR-INVALID-AMOUNT)
      
      ;; Burn stablecoins from user
      ;; (try! (contract-call? .stablecoin burn stable-amount tx-sender))
      
      ;; Update vault
      (map-set vaults vault-id (merge vault {
        debt: new-debt,
        last-updated: block-height
      }))
      
      ;; Update global state
      (var-set total-debt (- (var-get total-debt) stable-amount))
      
      (print {
        event: "debt-repaid",
        vault-id: vault-id,
        amount: stable-amount,
        remaining-debt: new-debt,
        owner: tx-sender
      })
      
      (ok new-debt))))

;; Withdraw collateral from vault
(define-public (withdraw-collateral (vault-id uint) (amount uint))
  (let (
    (vault (unwrap! (map-get? vaults vault-id) ERR-VAULT-NOT-FOUND))
    (current-collateral (get collateral vault))
    (current-debt (get debt vault))
    (btc-price (unwrap! (get-btc-price) ERR-ORACLE-STALE))
  )
    ;; Check ownership
    (asserts! (is-eq tx-sender (get owner vault)) ERR-VAULT-NOT-OWNER)
    
    ;; Check not paused
    (asserts! (not (var-get paused)) ERR-SYSTEM-PAUSED)
    
    ;; Check vault is active
    (asserts! (is-eq (get status vault) "active") ERR-VAULT-NOT-FOUND)
    
    ;; Check valid amount
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    ;; Check sufficient collateral
    (asserts! (<= amount current-collateral) ERR-WITHDRAW-EXCEEDS-AVAILABLE)
    
    (let (
      (new-collateral (- current-collateral amount))
    )
      ;; If there's debt, check collateral ratio is maintained
      (if (> current-debt u0)
        (let (
          (new-collateral-value (calculate-collateral-value new-collateral btc-price))
          (new-ratio (calculate-ratio new-collateral-value current-debt))
        )
          (asserts! (>= new-ratio (var-get min-collateral-ratio)) ERR-BELOW-MIN-COLLATERAL-RATIO)
          true)
        true)
      
      ;; Update vault
      (map-set vaults vault-id (merge vault {
        collateral: new-collateral,
        last-updated: block-height
      }))
      
      ;; Update global state
      (var-set total-collateral (- (var-get total-collateral) amount))
      
      ;; Transfer collateral to user
      ;; (try! (as-contract (contract-call? .wrapped-btc transfer amount tx-sender (get owner vault) none)))
      
      (print {
        event: "collateral-withdrawn",
        vault-id: vault-id,
        amount: amount,
        remaining-collateral: new-collateral,
        owner: tx-sender
      })
      
      (ok new-collateral))))

;; Close a vault (must have zero debt)
(define-public (close-vault (vault-id uint))
  (let (
    (vault (unwrap! (map-get? vaults vault-id) ERR-VAULT-NOT-FOUND))
    (remaining-collateral (get collateral vault))
  )
    ;; Check ownership
    (asserts! (is-eq tx-sender (get owner vault)) ERR-VAULT-NOT-OWNER)
    
    ;; Check vault is active
    (asserts! (is-eq (get status vault) "active") ERR-VAULT-NOT-FOUND)
    
    ;; Check no debt remaining
    (asserts! (is-eq (get debt vault) u0) ERR-VAULT-HAS-DEBT)
    
    ;; Return remaining collateral
    (if (> remaining-collateral u0)
      (begin
        ;; (try! (as-contract (contract-call? .wrapped-btc transfer remaining-collateral tx-sender (get owner vault) none)))
        (var-set total-collateral (- (var-get total-collateral) remaining-collateral))
        true)
      true)
    
    ;; Mark vault as closed
    (map-set vaults vault-id (merge vault {
      collateral: u0,
      status: "closed",
      last-updated: block-height
    }))
    
    (print {
      event: "vault-closed",
      vault-id: vault-id,
      returned-collateral: remaining-collateral,
      owner: tx-sender
    })
    
    (ok true)))

;; ============================================================================
;; LIQUIDATION INTERFACE
;; ============================================================================

;; Called by liquidation contract to seize collateral
(define-public (seize-collateral (vault-id uint) (collateral-amount uint) (debt-to-clear uint))
  (let (
    (vault (unwrap! (map-get? vaults vault-id) ERR-VAULT-NOT-FOUND))
  )
    ;; Only liquidation contract can call
    (asserts! (is-eq tx-sender (var-get liquidation-contract)) ERR-NOT-AUTHORIZED)
    
    ;; Update vault
    (map-set vaults vault-id (merge vault {
      collateral: (- (get collateral vault) collateral-amount),
      debt: (- (get debt vault) debt-to-clear),
      last-updated: block-height,
      status: (if (is-eq (- (get debt vault) debt-to-clear) u0) "liquidated" (get status vault))
    }))
    
    ;; Update global state
    (var-set total-collateral (- (var-get total-collateral) collateral-amount))
    (var-set total-debt (- (var-get total-debt) debt-to-clear))
    
    (print {
      event: "collateral-seized",
      vault-id: vault-id,
      collateral-seized: collateral-amount,
      debt-cleared: debt-to-clear
    })
    
    (ok true)))

;; ============================================================================
;; READ-ONLY FUNCTIONS
;; ============================================================================

;; Get vault details
(define-read-only (get-vault (vault-id uint))
  (map-get? vaults vault-id))

;; Get vault with calculated values
(define-read-only (get-vault-info (vault-id uint))
  (match (map-get? vaults vault-id)
    vault
      (let (
        (btc-price (get-btc-price-unsafe))
        (collateral-value (calculate-collateral-value (get collateral vault) btc-price))
        (ratio (if (> (get debt vault) u0)
                   (calculate-ratio collateral-value (get debt vault))
                   u0))
      )
        (some {
          vault-id: vault-id,
          owner: (get owner vault),
          collateral: (get collateral vault),
          debt: (get debt vault),
          collateral-value-usd: collateral-value,
          collateral-ratio: ratio,
          is-liquidatable: (and (> (get debt vault) u0) (< ratio (var-get liquidation-ratio))),
          status: (get status vault),
          created-at: (get created-at vault),
          last-updated: (get last-updated vault)
        }))
    none))

;; Get collateral ratio for a vault
(define-read-only (get-collateral-ratio (vault-id uint))
  (match (map-get? vaults vault-id)
    vault
      (let (
        (btc-price (get-btc-price-unsafe))
        (collateral-value (calculate-collateral-value (get collateral vault) btc-price))
      )
        (if (> (get debt vault) u0)
            (calculate-ratio collateral-value (get debt vault))
            u0))
    u0))

;; Check if vault is liquidatable
(define-read-only (is-liquidatable (vault-id uint))
  (match (map-get? vaults vault-id)
    vault
      (let (
        (btc-price (get-btc-price-unsafe))
        (collateral-value (calculate-collateral-value (get collateral vault) btc-price))
        (ratio (calculate-ratio collateral-value (get debt vault)))
      )
        (and (> (get debt vault) u0) 
             (< ratio (var-get liquidation-ratio))
             (is-eq (get status vault) "active")))
    false))

;; Get user's vault IDs
(define-read-only (get-user-vaults (user principal))
  (default-to (list) (map-get? user-vaults user)))

;; Check if BTC tx has been processed
(define-read-only (is-tx-processed (btc-txid (buff 36)))
  (is-some (map-get? processed-btc-txs btc-txid)))

;; Get system parameters
(define-read-only (get-system-params)
  {
    min-collateral-ratio: (var-get min-collateral-ratio),
    liquidation-ratio: (var-get liquidation-ratio),
    total-collateral: (var-get total-collateral),
    total-debt: (var-get total-debt),
    vault-count: (var-get vault-counter),
    paused: (var-get paused)
  })

;; Get global system health
(define-read-only (get-system-health)
  (let (
    (btc-price (get-btc-price-unsafe))
    (total-col (var-get total-collateral))
    (total-dbt (var-get total-debt))
    (collateral-value (calculate-collateral-value total-col btc-price))
  )
    {
      total-collateral-btc: total-col,
      total-collateral-usd: collateral-value,
      total-debt: total-dbt,
      system-collateral-ratio: (if (> total-dbt u0) (calculate-ratio collateral-value total-dbt) u0),
      btc-price: btc-price
    }))

;; ============================================================================
;; HELPER FUNCTIONS
;; ============================================================================

;; Calculate collateral value in USD (scaled by stablecoin scale)
(define-read-only (calculate-collateral-value (collateral-amount uint) (btc-price uint))
  ;; collateral is in satoshis (1e8), price is in USD scaled by 1e8
  ;; Result should be in stablecoin units (1e6)
  ;; value = collateral * price / PRICE_SCALE / (COLLATERAL_SCALE / STABLECOIN_SCALE)
  (/ (* collateral-amount btc-price) (* PRICE-SCALE (/ COLLATERAL-SCALE STABLECOIN-SCALE))))

;; Calculate collateral ratio in basis points
(define-read-only (calculate-ratio (collateral-value uint) (debt uint))
  (if (is-eq debt u0)
      u0
      (/ (* collateral-value BPS) debt)))

;; Get BTC price from oracle
(define-private (get-btc-price)
  ;; In production: (contract-call? .oracle get-price)
  ;; For now, return a mock value or read from oracle contract
  (ok u5000000000000)) ;; $50,000 in 1e8 scale

;; Get BTC price unsafe (no staleness check)
(define-read-only (get-btc-price-unsafe)
  ;; In production: (contract-call? .oracle get-price-unsafe)
  u5000000000000)

;; ============================================================================
;; ADMIN FUNCTIONS
;; ============================================================================

;; Set minimum collateral ratio
(define-public (set-min-collateral-ratio (new-ratio uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)
    ;; Must be at least 100% and reasonable (max 500%)
    (asserts! (and (>= new-ratio BPS) (<= new-ratio u50000)) (err u5021))
    ;; Must be higher than liquidation ratio
    (asserts! (> new-ratio (var-get liquidation-ratio)) (err u5022))
    
    (var-set min-collateral-ratio new-ratio)
    (print {event: "min-collateral-ratio-updated", ratio: new-ratio})
    (ok true)))

;; Set liquidation ratio
(define-public (set-liquidation-ratio (new-ratio uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)
    ;; Must be at least 100% and less than min-collateral-ratio
    (asserts! (and (>= new-ratio BPS) (< new-ratio (var-get min-collateral-ratio))) (err u5023))
    
    (var-set liquidation-ratio new-ratio)
    (print {event: "liquidation-ratio-updated", ratio: new-ratio})
    (ok true)))

;; Set chainhook relayer address
(define-public (set-relayer (new-relayer principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)
    (var-set chainhook-relayer new-relayer)
    (print {event: "relayer-updated", relayer: new-relayer})
    (ok true)))

;; Set contract references
(define-public (set-contracts 
  (oracle principal)
  (stablecoin principal)
  (fees principal)
  (liquidation principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)
    (var-set oracle-contract oracle)
    (var-set stablecoin-contract stablecoin)
    (var-set fees-contract fees)
    (var-set liquidation-contract liquidation)
    (print {event: "contracts-updated"})
    (ok true)))

;; Pause/unpause system
(define-public (set-paused (is-paused bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)
    (var-set paused is-paused)
    (print {event: "pause-updated", paused: is-paused})
    (ok true)))

;; Transfer admin
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)
    (var-set contract-admin new-admin)
    (print {event: "admin-transferred", new-admin: new-admin})
    (ok true)))

```
