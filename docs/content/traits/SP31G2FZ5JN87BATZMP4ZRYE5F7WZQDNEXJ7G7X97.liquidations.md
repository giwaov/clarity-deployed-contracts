---
title: "Trait liquidations"
draft: true
---
```
;; ============================================================================
;; LIQUIDATIONS.CLAR - Vault Liquidation System
;; ============================================================================
;; Handles the liquidation of under-collateralized vaults.
;; Anyone can trigger liquidation of unhealthy vaults and receive
;; collateral at a discount (liquidation penalty becomes liquidator bonus).
;; ============================================================================

;; ============================================================================
;; CONSTANTS
;; ============================================================================

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u6000))
(define-constant ERR-VAULT-NOT-FOUND (err u6001))
(define-constant ERR-VAULT-NOT-LIQUIDATABLE (err u6002))
(define-constant ERR-INVALID-AMOUNT (err u6003))
(define-constant ERR-SYSTEM-PAUSED (err u6004))
(define-constant ERR-ORACLE-STALE (err u6005))
(define-constant ERR-INSUFFICIENT-REPAY (err u6006))
(define-constant ERR-LIQUIDATION-TOO-LARGE (err u6007))
(define-constant ERR-AUCTION-NOT-FOUND (err u6008))
(define-constant ERR-AUCTION-ENDED (err u6009))
(define-constant ERR-BID-TOO-LOW (err u6010))
(define-constant ERR-NOT-AUCTION-WINNER (err u6011))

;; Precision constants
(define-constant PRICE-SCALE u100000000)
(define-constant COLLATERAL-SCALE u100000000)
(define-constant STABLECOIN-SCALE u1000000)
(define-constant BPS u10000)

;; Liquidation parameters
(define-constant MIN-LIQUIDATION-AMOUNT u1000000)     ;; Min 1 BTCD to liquidate
(define-constant MAX-LIQUIDATION-PERCENT u5000)       ;; Max 50% of vault per liquidation
(define-constant AUCTION-DURATION u144)               ;; ~1 day in blocks

;; ============================================================================
;; DATA STORAGE
;; ============================================================================

;; Liquidation penalty (bonus for liquidator) in BPS
(define-data-var liquidation-penalty uint u1000)  ;; 10%

;; Liquidation ratio (below this, vault is liquidatable)
(define-data-var liquidation-ratio uint u13000)   ;; 130%

;; Close factor - max percentage of debt that can be liquidated at once
(define-data-var close-factor uint u5000)         ;; 50%

;; Contract references
(define-data-var vaults-contract principal tx-sender)
(define-data-var stablecoin-contract principal tx-sender)
(define-data-var oracle-contract principal tx-sender)
(define-data-var fees-contract principal tx-sender)

;; System state
(define-data-var paused bool false)
(define-data-var contract-admin principal tx-sender)

;; Liquidation statistics
(define-data-var total-liquidations uint u0)
(define-data-var total-collateral-liquidated uint u0)
(define-data-var total-debt-liquidated uint u0)

;; Auction counter
(define-data-var auction-counter uint u0)

;; Active auctions (for auction-based liquidation mode)
(define-map auctions
  uint  ;; auction-id
  {
    vault-id: uint,
    collateral-amount: uint,
    debt-to-cover: uint,
    start-block: uint,
    end-block: uint,
    highest-bid: uint,
    highest-bidder: (optional principal),
    status: (string-ascii 10)  ;; "active", "settled", "cancelled"
  })

;; Liquidation records
(define-map liquidation-history
  uint  ;; liquidation-id (using total-liquidations as counter)
  {
    vault-id: uint,
    liquidator: principal,
    debt-repaid: uint,
    collateral-seized: uint,
    penalty-amount: uint,
    btc-price: uint,
    block: uint
  })

;; ============================================================================
;; DIRECT LIQUIDATION (Primary Mode)
;; ============================================================================

;; Liquidate an under-collateralized vault
;; Liquidator repays some debt and receives collateral at a discount
;; @param vault-id: The vault to liquidate
;; @param max-repay: Maximum debt the liquidator is willing to repay
(define-public (liquidate (vault-id uint) (max-repay uint))
  (let (
    (vault-info (unwrap! (get-vault-data vault-id) ERR-VAULT-NOT-FOUND))
    (btc-price (unwrap! (get-btc-price) ERR-ORACLE-STALE))
    (collateral-value (calculate-collateral-value (get collateral vault-info) btc-price))
    (current-ratio (calculate-ratio collateral-value (get debt vault-info)))
  )
    ;; Check system not paused
    (asserts! (not (var-get paused)) ERR-SYSTEM-PAUSED)
    
    ;; Check vault is liquidatable
    (asserts! (< current-ratio (var-get liquidation-ratio)) ERR-VAULT-NOT-LIQUIDATABLE)
    (asserts! (> (get debt vault-info) u0) ERR-VAULT-NOT-LIQUIDATABLE)
    (asserts! (is-eq (get status vault-info) "active") ERR-VAULT-NOT-FOUND)
    
    ;; Check valid repay amount
    (asserts! (> max-repay u0) ERR-INVALID-AMOUNT)
    (asserts! (>= max-repay MIN-LIQUIDATION-AMOUNT) ERR-INSUFFICIENT-REPAY)
    
    (let (
      ;; Calculate maximum repayable (close factor)
      (max-repayable (/ (* (get debt vault-info) (var-get close-factor)) BPS))
      (actual-repay (if (< max-repay max-repayable) max-repay max-repayable))
      
      ;; Calculate collateral to seize (debt value + penalty)
      (collateral-to-seize (calculate-seize-amount actual-repay btc-price))
      
      ;; Ensure we don't seize more than available
      (final-collateral-seize (if (> collateral-to-seize (get collateral vault-info))
                                   (get collateral vault-info)
                                   collateral-to-seize))
      
      ;; Calculate actual debt we can cover with available collateral
      (final-repay (if (> collateral-to-seize (get collateral vault-info))
                       (calculate-debt-from-collateral (get collateral vault-info) btc-price)
                       actual-repay))
      
      ;; Calculate penalty
      (penalty-value (/ (* final-collateral-seize (var-get liquidation-penalty)) 
                        (+ BPS (var-get liquidation-penalty))))
    )
      ;; Transfer stablecoins from liquidator (would burn via vaults contract)
      ;; (try! (contract-call? .stablecoin burn final-repay tx-sender))
      
      ;; Tell vaults contract to seize collateral
      ;; (try! (contract-call? .vaults seize-collateral vault-id final-collateral-seize final-repay))
      
      ;; Transfer collateral to liquidator
      ;; (try! (as-contract (contract-call? .wrapped-btc transfer final-collateral-seize tx-sender tx-sender none)))
      
      ;; Record liquidation penalty
      ;; (try! (contract-call? .fees record-liquidation-penalty penalty-value vault-id))
      
      ;; Update statistics
      (var-set total-liquidations (+ (var-get total-liquidations) u1))
      (var-set total-collateral-liquidated (+ (var-get total-collateral-liquidated) final-collateral-seize))
      (var-set total-debt-liquidated (+ (var-get total-debt-liquidated) final-repay))
      
      ;; Record in history
      (map-set liquidation-history (var-get total-liquidations) {
        vault-id: vault-id,
        liquidator: tx-sender,
        debt-repaid: final-repay,
        collateral-seized: final-collateral-seize,
        penalty-amount: penalty-value,
        btc-price: btc-price,
        block: block-height
      })
      
      (print {
        event: "vault-liquidated",
        liquidation-id: (var-get total-liquidations),
        vault-id: vault-id,
        liquidator: tx-sender,
        debt-repaid: final-repay,
        collateral-seized: final-collateral-seize,
        penalty-bonus: penalty-value,
        btc-price: btc-price,
        vault-ratio-before: current-ratio
      })
      
      (ok {
        debt-repaid: final-repay,
        collateral-received: final-collateral-seize,
        penalty-bonus: penalty-value
      }))))

;; ============================================================================
;; AUCTION-BASED LIQUIDATION (Alternative Mode)
;; ============================================================================

;; Start a collateral auction for a liquidatable vault
(define-public (start-auction (vault-id uint))
  (let (
    (vault-info (unwrap! (get-vault-data vault-id) ERR-VAULT-NOT-FOUND))
    (btc-price (unwrap! (get-btc-price) ERR-ORACLE-STALE))
    (collateral-value (calculate-collateral-value (get collateral vault-info) btc-price))
    (current-ratio (calculate-ratio collateral-value (get debt vault-info)))
    (auction-id (+ (var-get auction-counter) u1))
  )
    ;; Check system not paused
    (asserts! (not (var-get paused)) ERR-SYSTEM-PAUSED)
    
    ;; Check vault is liquidatable
    (asserts! (< current-ratio (var-get liquidation-ratio)) ERR-VAULT-NOT-LIQUIDATABLE)
    
    ;; Calculate auction parameters
    (let (
      (collateral-to-auction (get collateral vault-info))
      (debt-to-cover (get debt vault-info))
    )
      ;; Create auction
      (map-set auctions auction-id {
        vault-id: vault-id,
        collateral-amount: collateral-to-auction,
        debt-to-cover: debt-to-cover,
        start-block: block-height,
        end-block: (+ block-height AUCTION-DURATION),
        highest-bid: debt-to-cover,  ;; Start bid at debt amount
        highest-bidder: none,
        status: "active"
      })
      
      (var-set auction-counter auction-id)
      
      (print {
        event: "auction-started",
        auction-id: auction-id,
        vault-id: vault-id,
        collateral: collateral-to-auction,
        starting-bid: debt-to-cover,
        end-block: (+ block-height AUCTION-DURATION)
      })
      
      (ok auction-id))))

;; Place a bid on an auction
;; Bidding is for the amount of stablecoins willing to pay for the collateral
(define-public (bid (auction-id uint) (bid-amount uint))
  (let (
    (auction (unwrap! (map-get? auctions auction-id) ERR-AUCTION-NOT-FOUND))
  )
    ;; Check auction is active
    (asserts! (is-eq (get status auction) "active") ERR-AUCTION-ENDED)
    (asserts! (<= block-height (get end-block auction)) ERR-AUCTION-ENDED)
    
    ;; Check bid is higher than current (reverse auction - lower debt acceptance wins)
    ;; OR in standard auction, higher bid wins
    (asserts! (> bid-amount (get highest-bid auction)) ERR-BID-TOO-LOW)
    
    ;; Lock bid amount from bidder
    ;; (try! (contract-call? .stablecoin transfer bid-amount tx-sender (as-contract tx-sender) none))
    
    ;; Return previous bidder's funds if any
    (match (get highest-bidder auction)
      prev-bidder 
        ;; (try! (as-contract (contract-call? .stablecoin transfer (get highest-bid auction) tx-sender prev-bidder none)))
        true
      true)
    
    ;; Update auction
    (map-set auctions auction-id (merge auction {
      highest-bid: bid-amount,
      highest-bidder: (some tx-sender)
    }))
    
    (print {
      event: "bid-placed",
      auction-id: auction-id,
      bidder: tx-sender,
      bid-amount: bid-amount
    })
    
    (ok true)))

;; Settle a completed auction
(define-public (settle-auction (auction-id uint))
  (let (
    (auction (unwrap! (map-get? auctions auction-id) ERR-AUCTION-NOT-FOUND))
  )
    ;; Check auction has ended
    (asserts! (> block-height (get end-block auction)) (err u6012))
    (asserts! (is-eq (get status auction) "active") ERR-AUCTION-ENDED)
    
    (match (get highest-bidder auction)
      winner
        (begin
          ;; Burn the winning bid (debt repayment)
          ;; (try! (as-contract (contract-call? .stablecoin burn (get highest-bid auction) tx-sender)))
          
          ;; Transfer collateral to winner
          ;; (try! (contract-call? .vaults seize-collateral (get vault-id auction) (get collateral-amount auction) (get debt-to-cover auction)))
          ;; (try! (as-contract (contract-call? .wrapped-btc transfer (get collateral-amount auction) tx-sender winner none)))
          
          ;; Mark auction as settled
          (map-set auctions auction-id (merge auction {status: "settled"}))
          
          (print {
            event: "auction-settled",
            auction-id: auction-id,
            winner: winner,
            winning-bid: (get highest-bid auction),
            collateral-transferred: (get collateral-amount auction)
          })
          
          (ok true))
      ;; No bids - cancel auction
      (begin
        (map-set auctions auction-id (merge auction {status: "cancelled"}))
        (print {event: "auction-cancelled", auction-id: auction-id, reason: "no-bids"})
        (ok true)))))

;; ============================================================================
;; READ-ONLY FUNCTIONS
;; ============================================================================

;; Check if a vault is liquidatable
(define-read-only (check-liquidatable (vault-id uint))
  (match (get-vault-data vault-id)
    vault-info
      (let (
        (btc-price (get-btc-price-unsafe))
        (collateral-value (calculate-collateral-value (get collateral vault-info) btc-price))
        (ratio (calculate-ratio collateral-value (get debt vault-info)))
      )
        {
          is-liquidatable: (and (> (get debt vault-info) u0) 
                                (< ratio (var-get liquidation-ratio))),
          current-ratio: ratio,
          liquidation-ratio: (var-get liquidation-ratio),
          debt: (get debt vault-info),
          collateral: (get collateral vault-info),
          collateral-value: collateral-value
        })
    {
      is-liquidatable: false,
      current-ratio: u0,
      liquidation-ratio: (var-get liquidation-ratio),
      debt: u0,
      collateral: u0,
      collateral-value: u0
    }))

;; Calculate how much collateral a liquidator would receive for repaying debt
(define-read-only (preview-liquidation (vault-id uint) (repay-amount uint))
  (match (get-vault-data vault-id)
    vault-info
      (let (
        (btc-price (get-btc-price-unsafe))
        (max-repayable (/ (* (get debt vault-info) (var-get close-factor)) BPS))
        (actual-repay (if (< repay-amount max-repayable) repay-amount max-repayable))
        (collateral-seize (calculate-seize-amount actual-repay btc-price))
        (penalty (/ (* collateral-seize (var-get liquidation-penalty)) 
                    (+ BPS (var-get liquidation-penalty))))
      )
        {
          repay-amount: actual-repay,
          collateral-received: (if (> collateral-seize (get collateral vault-info))
                                   (get collateral vault-info)
                                   collateral-seize),
          penalty-bonus: penalty,
          max-repayable: max-repayable
        })
    {
      repay-amount: u0,
      collateral-received: u0,
      penalty-bonus: u0,
      max-repayable: u0
    }))

;; Get liquidation statistics
(define-read-only (get-liquidation-stats)
  {
    total-liquidations: (var-get total-liquidations),
    total-collateral-liquidated: (var-get total-collateral-liquidated),
    total-debt-liquidated: (var-get total-debt-liquidated),
    liquidation-penalty: (var-get liquidation-penalty),
    liquidation-ratio: (var-get liquidation-ratio),
    close-factor: (var-get close-factor)
  })

;; Get auction details
(define-read-only (get-auction (auction-id uint))
  (map-get? auctions auction-id))

;; Get liquidation record
(define-read-only (get-liquidation-record (liquidation-id uint))
  (map-get? liquidation-history liquidation-id))

;; ============================================================================
;; HELPER FUNCTIONS
;; ============================================================================

;; Calculate collateral to seize for a given debt repayment
;; Includes liquidation penalty bonus for liquidator
(define-read-only (calculate-seize-amount (debt-to-repay uint) (btc-price uint))
  (let (
    ;; Base collateral value to cover debt
    ;; collateral = debt * COLLATERAL_SCALE * PRICE_SCALE / (price * STABLECOIN_SCALE)
    (base-collateral (/ (* (* debt-to-repay COLLATERAL-SCALE) PRICE-SCALE) 
                        (* btc-price STABLECOIN-SCALE)))
    ;; Add penalty bonus
    (with-penalty (/ (* base-collateral (+ BPS (var-get liquidation-penalty))) BPS))
  )
    with-penalty))

;; Calculate debt that can be covered with given collateral
(define-read-only (calculate-debt-from-collateral (collateral uint) (btc-price uint))
  (let (
    (collateral-value (/ (* collateral btc-price) PRICE-SCALE))
    ;; Remove penalty from calculation
    (debt-coverable (/ (* collateral-value STABLECOIN-SCALE BPS) 
                       (* COLLATERAL-SCALE (+ BPS (var-get liquidation-penalty)))))
  )
    debt-coverable))

;; Calculate collateral value in stablecoin units
(define-read-only (calculate-collateral-value (collateral uint) (btc-price uint))
  (/ (* collateral btc-price) (* PRICE-SCALE (/ COLLATERAL-SCALE STABLECOIN-SCALE))))

;; Calculate collateral ratio
(define-read-only (calculate-ratio (collateral-value uint) (debt uint))
  (if (is-eq debt u0)
      u0
      (/ (* collateral-value BPS) debt)))

;; Get vault data (mock - would call vaults contract)
(define-private (get-vault-data (vault-id uint))
  ;; In production: (contract-call? .vaults get-vault vault-id)
  (some {
    owner: tx-sender,
    collateral: u100000000,  ;; 1 BTC
    debt: u40000000000,      ;; 40,000 BTCD
    status: "active"
  }))

;; Get BTC price from oracle
(define-private (get-btc-price)
  ;; In production: (contract-call? .oracle get-price)
  (ok u5000000000000)) ;; $50,000

;; Get price unsafe
(define-read-only (get-btc-price-unsafe)
  u5000000000000)

;; ============================================================================
;; ADMIN FUNCTIONS
;; ============================================================================

;; Set liquidation penalty
(define-public (set-liquidation-penalty (new-penalty uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)
    ;; 1% to 50% range
    (asserts! (and (>= new-penalty u100) (<= new-penalty u5000)) (err u6013))
    
    (var-set liquidation-penalty new-penalty)
    (print {event: "liquidation-penalty-updated", penalty-bps: new-penalty})
    (ok true)))

;; Set liquidation ratio
(define-public (set-liquidation-ratio (new-ratio uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)
    ;; 100% to 200% range
    (asserts! (and (>= new-ratio BPS) (<= new-ratio u20000)) (err u6014))
    
    (var-set liquidation-ratio new-ratio)
    (print {event: "liquidation-ratio-updated", ratio-bps: new-ratio})
    (ok true)))

;; Set close factor
(define-public (set-close-factor (new-factor uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)
    ;; 10% to 100% range
    (asserts! (and (>= new-factor u1000) (<= new-factor BPS)) (err u6015))
    
    (var-set close-factor new-factor)
    (print {event: "close-factor-updated", factor-bps: new-factor})
    (ok true)))

;; Set contract references
(define-public (set-contracts 
  (vaults principal)
  (stablecoin principal)
  (oracle principal)
  (fees principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)
    (var-set vaults-contract vaults)
    (var-set stablecoin-contract stablecoin)
    (var-set oracle-contract oracle)
    (var-set fees-contract fees)
    (print {event: "contracts-updated"})
    (ok true)))

;; Pause/unpause
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
