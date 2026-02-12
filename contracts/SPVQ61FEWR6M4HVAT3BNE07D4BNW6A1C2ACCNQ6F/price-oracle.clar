;; Price Oracle Contract
;; Manages price feeds for collateral assets (STX and potentially other tokens)

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_PRICE_TOO_OLD (err u401))
(define-constant ERR_INVALID_PRICE (err u402))
(define-constant ERR_ASSET_NOT_SUPPORTED (err u403))
(define-constant ERR_ORACLE_NOT_AUTHORIZED (err u404))
(define-constant ERR_PRICE_DEVIATION_TOO_HIGH (err u405))

;; Price staleness threshold (144 blocks = ~24 hours with 10min blocks)
(define-constant PRICE_STALENESS_THRESHOLD u144)

;; Maximum price deviation allowed between updates (10%)
(define-constant MAX_PRICE_DEVIATION u10)
(define-constant PRICE_DEVIATION_DENOMINATOR u100)

;; Price precision
(define-constant PRICE_PRECISION u1000000) ;; 6 decimals

;; Data Variables
(define-data-var oracle-admin principal CONTRACT_OWNER)
(define-data-var price-update-count uint u0)
(define-data-var emergency-pause bool false)

;; Data Maps
(define-map asset-prices
  { asset: (string-ascii 10) }
  {
    price: uint,
    last-update-block: uint,
    last-update-time: uint,
    decimals: uint,
    source: (string-ascii 20)
  }
)

(define-map authorized-oracles
  principal
  { authorized: bool, update-count: uint }
)

(define-map price-history
  { asset: (string-ascii 10), block: uint }
  { price: uint, source: (string-ascii 20) }
)

(define-map asset-config
  { asset: (string-ascii 10) }
  {
    supported: bool,
    min-price: uint,
    max-price: uint,
    decimals: uint
  }
)

;; Multi-source price aggregation
(define-map price-sources
  { asset: (string-ascii 10), source: (string-ascii 20) }
  {
    price: uint,
    weight: uint,
    last-update: uint,
    active: bool
  }
)

;; Read-only functions

(define-read-only (get-price (asset (string-ascii 10)))
  (match (map-get? asset-prices { asset: asset })
    price-data
      (let
        (
          (blocks-since-update (- block-height (get last-update-block price-data)))
        )
        ;; Check if price is too old
        (if (> blocks-since-update PRICE_STALENESS_THRESHOLD)
          ERR_PRICE_TOO_OLD
          (ok price-data)
        )
      )
    ERR_ASSET_NOT_SUPPORTED
  )
)

(define-read-only (get-latest-price (asset (string-ascii 10)))
  (match (get-price asset)
    price-data (ok (get price price-data))
    error (err error)
  )
)

(define-read-only (is-price-fresh (asset (string-ascii 10)))
  (match (map-get? asset-prices { asset: asset })
    price-data
      (let
        (
          (blocks-since-update (- block-height (get last-update-block price-data)))
        )
        (ok (<= blocks-since-update PRICE_STALENESS_THRESHOLD))
      )
    ERR_ASSET_NOT_SUPPORTED
  )
)

(define-read-only (get-asset-config (asset (string-ascii 10)))
  (map-get? asset-config { asset: asset })
)

(define-read-only (is-oracle-authorized (oracle principal))
  (default-to 
    { authorized: false, update-count: u0 }
    (map-get? authorized-oracles oracle)
  )
)

(define-read-only (get-price-at-block (asset (string-ascii 10)) (block uint))
  (map-get? price-history { asset: asset, block: block })
)

(define-read-only (calculate-twap 
  (asset (string-ascii 10)) 
  (start-block uint) 
  (end-block uint))
  ;; Time-Weighted Average Price calculation
  ;; This is a simplified version - production would need more sophisticated TWAP
  (match (map-get? asset-prices { asset: asset })
    current-price-data
      (let
        (
          (current-price (get price current-price-data))
        )
        ;; For now, return current price
        ;; Full implementation would aggregate historical prices
        (ok current-price)
      )
    ERR_ASSET_NOT_SUPPORTED
  )
)

(define-read-only (get-price-deviation (old-price uint) (new-price uint))
  (if (is-eq old-price u0)
    u0
    (let
      (
        (difference (if (> new-price old-price)
          (- new-price old-price)
          (- old-price new-price)))
        (deviation (/ (* difference PRICE_DEVIATION_DENOMINATOR) old-price))
      )
      deviation
    )
  )
)

(define-read-only (is-emergency-paused)
  (var-get emergency-pause)
)

;; Public functions

(define-public (update-price 
  (asset (string-ascii 10)) 
  (new-price uint)
  (source (string-ascii 20)))
  (begin
    (asserts! (not (var-get emergency-pause)) ERR_UNAUTHORIZED)
    
    ;; Check authorization
    (let
      (
        (oracle-info (is-oracle-authorized tx-sender))
      )
      (asserts! (get authorized oracle-info) ERR_ORACLE_NOT_AUTHORIZED)
    )
    
    ;; Validate asset is supported
    (let
      (
        (config (unwrap! (get-asset-config asset) ERR_ASSET_NOT_SUPPORTED))
      )
      (asserts! (get supported config) ERR_ASSET_NOT_SUPPORTED)
      
      ;; Validate price is within bounds
      (asserts! (>= new-price (get min-price config)) ERR_INVALID_PRICE)
      (asserts! (<= new-price (get max-price config)) ERR_INVALID_PRICE)
      
      ;; Check price deviation if previous price exists
      (match (map-get? asset-prices { asset: asset })
        old-price-data
          (let
            (
              (old-price (get price old-price-data))
              (deviation (get-price-deviation old-price new-price))
            )
            (asserts! (<= deviation MAX_PRICE_DEVIATION) ERR_PRICE_DEVIATION_TOO_HIGH)
            true
          )
        true ;; No previous price, allow any valid price
      )
      
      ;; Update price
      (map-set asset-prices { asset: asset }
        {
          price: new-price,
          last-update-block: block-height,
          last-update-time: burn-block-height,
          decimals: (get decimals config),
          source: source
        }
      )
      
      ;; Store in history
      (map-set price-history { asset: asset, block: block-height }
        { price: new-price, source: source }
      )
      
      ;; Update oracle stats
      (let
        (
          (oracle-info (is-oracle-authorized tx-sender))
        )
        (map-set authorized-oracles tx-sender
          (merge oracle-info { update-count: (+ (get update-count oracle-info) u1) })
        )
      )
      
      ;; Increment global counter
      (var-set price-update-count (+ (var-get price-update-count) u1))
      
      (ok true)
    )
  )
)

(define-public (update-multi-source-price
  (asset (string-ascii 10))
  (source (string-ascii 20))
  (price uint)
  (weight uint))
  (begin
    (asserts! (not (var-get emergency-pause)) ERR_UNAUTHORIZED)
    
    ;; Check authorization
    (let
      (
        (oracle-info (is-oracle-authorized tx-sender))
      )
      (asserts! (get authorized oracle-info) ERR_ORACLE_NOT_AUTHORIZED)
    )
    
    ;; Update source price
    (map-set price-sources { asset: asset, source: source }
      {
        price: price,
        weight: weight,
        last-update: block-height,
        active: true
      }
    )
    
    (ok true)
  )
)

;; Admin functions

(define-public (add-supported-asset
  (asset (string-ascii 10))
  (min-price uint)
  (max-price uint)
  (decimals uint))
  (begin
    (asserts! (is-eq tx-sender (var-get oracle-admin)) ERR_UNAUTHORIZED)
    
    (map-set asset-config { asset: asset }
      {
        supported: true,
        min-price: min-price,
        max-price: max-price,
        decimals: decimals
      }
    )
    
    (ok true)
  )
)

(define-public (authorize-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get oracle-admin)) ERR_UNAUTHORIZED)
    
    (map-set authorized-oracles oracle
      { authorized: true, update-count: u0 }
    )
    
    (ok true)
  )
)

(define-public (revoke-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get oracle-admin)) ERR_UNAUTHORIZED)
    
    (map-set authorized-oracles oracle
      { authorized: false, update-count: u0 }
    )
    
    (ok true)
  )
)

(define-public (set-emergency-pause (paused bool))
  (begin
    (asserts! (is-eq tx-sender (var-get oracle-admin)) ERR_UNAUTHORIZED)
    (var-set emergency-pause paused)
    (ok paused)
  )
)

(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get oracle-admin)) ERR_UNAUTHORIZED)
    (var-set oracle-admin new-admin)
    (ok true)
  )
)

;; Helper functions for price conversion

(define-read-only (convert-price-decimals 
  (price uint) 
  (from-decimals uint) 
  (to-decimals uint))
  (if (is-eq from-decimals to-decimals)
    price
    (if (> from-decimals to-decimals)
      ;; Reduce decimals - use direct division for common cases
      (let ((diff (- from-decimals to-decimals)))
        (if (is-eq diff u1)
          (/ price u10)
          (if (is-eq diff u2)
            (/ price u100)
            (if (is-eq diff u3)
              (/ price u1000)
              (if (is-eq diff u4)
                (/ price u10000)
                (if (is-eq diff u5)
                  (/ price u100000)
                  (if (is-eq diff u6)
                    (/ price u1000000)
                    (/ price u1000000) ;; Default to 6 decimals
                  )
                )
              )
            )
          )
        )
      )
      ;; Increase decimals
      (let ((diff (- to-decimals from-decimals)))
        (if (is-eq diff u1)
          (* price u10)
          (if (is-eq diff u2)
            (* price u100)
            (if (is-eq diff u3)
              (* price u1000)
              (if (is-eq diff u4)
                (* price u10000)
                (if (is-eq diff u5)
                  (* price u100000)
                  (if (is-eq diff u6)
                    (* price u1000000)
                    (* price u1000000) ;; Default to 6 decimals
                  )
                )
              )
            )
          )
        )
      )
    )
  )
)

;; Initialize with default configuration
(begin
  ;; Authorize contract owner as oracle
  (map-set authorized-oracles CONTRACT_OWNER
    { authorized: true, update-count: u0 }
  )
  
  ;; Configure STX as supported asset
  (map-set asset-config { asset: "STX" }
    {
      supported: true,
      min-price: u100000,      ;; Min $0.10
      max-price: u100000000,   ;; Max $100
      decimals: u6
    }
  )
  
  ;; Set initial STX price ($1.00)
  (map-set asset-prices { asset: "STX" }
    {
      price: u1000000,
      last-update-block: u0,
      last-update-time: u0,
      decimals: u6,
      source: "INIT"
    }
  )
)
