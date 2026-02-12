---
title: "Trait oracle"
draft: true
---
```
;; ============================================================================
;; ORACLE.CLAR - BTC/USD Price Oracle
;; ============================================================================
;; Provides BTC/USD price feed for the stablecoin system.
;; Includes staleness checks, bounds validation, and multi-publisher support.
;; Price is stored in fixed-point format with 8 decimal places (1e8 scale).
;; ============================================================================

;; ============================================================================
;; IMPORTS
;; ============================================================================

;; Import access control
;; (use-trait access-trait .access.access-trait)

;; ============================================================================
;; CONSTANTS
;; ============================================================================

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u2000))
(define-constant ERR-PRICE-STALE (err u2001))
(define-constant ERR-PRICE-OUT-OF-BOUNDS (err u2002))
(define-constant ERR-ZERO-PRICE (err u2003))
(define-constant ERR-SYSTEM-PAUSED (err u2004))
(define-constant ERR-PRICE-NOT-SET (err u2005))
(define-constant ERR-DEVIATION-TOO-HIGH (err u2006))
(define-constant ERR-INVALID-TIMESTAMP (err u2007))

;; Price scale: 1e8 (8 decimal places)
;; Example: $50,000.00 = 5000000000000 (50000 * 1e8)
(define-constant PRICE-SCALE u100000000)

;; Default parameters
(define-constant DEFAULT-STALENESS-THRESHOLD u144)   ;; ~1 day at 10 min blocks
(define-constant DEFAULT-MIN-PRICE u100000000000)    ;; $1,000 minimum BTC price
(define-constant DEFAULT-MAX-PRICE u100000000000000) ;; $1,000,000 maximum BTC price
(define-constant DEFAULT-MAX-DEVIATION u1000)        ;; 10% max deviation (in BPS)

;; Basis points scale
(define-constant BPS u10000)

;; ============================================================================
;; DATA STORAGE
;; ============================================================================

;; Current price data
(define-data-var current-price uint u0)
(define-data-var price-block uint u0)
(define-data-var price-timestamp uint u0)
(define-data-var last-publisher principal tx-sender)

;; Oracle parameters (admin configurable)
(define-data-var staleness-threshold uint DEFAULT-STALENESS-THRESHOLD)
(define-data-var min-price uint DEFAULT-MIN-PRICE)
(define-data-var max-price uint DEFAULT-MAX-PRICE)
(define-data-var max-deviation-bps uint DEFAULT-MAX-DEVIATION)

;; Access control contract reference
(define-data-var access-contract principal tx-sender)

;; Price history for TWAP calculations (circular buffer of last N prices)
(define-constant PRICE-HISTORY-SIZE u10)
(define-map price-history uint {price: uint, block: uint})
(define-data-var price-history-index uint u0)

;; Publisher whitelist (in addition to role-based access)
(define-map trusted-publishers principal bool)

;; Circuit breaker state
(define-data-var circuit-breaker-active bool false)
(define-data-var circuit-breaker-block uint u0)

;; ============================================================================
;; INITIALIZATION
;; ============================================================================

;; Set the access control contract
(define-public (set-access-contract (access principal))
  (begin
    ;; Only deployer or current access contract admin can change this
    (asserts! (is-eq tx-sender (var-get access-contract)) ERR-NOT-AUTHORIZED)
    (var-set access-contract access)
    (print {event: "access-contract-set", access: access})
    (ok true)))

;; Add a trusted publisher
(define-public (add-publisher (publisher principal))
  (begin
    (asserts! (is-admin-caller) ERR-NOT-AUTHORIZED)
    (map-set trusted-publishers publisher true)
    (print {event: "publisher-added", publisher: publisher})
    (ok true)))

;; Remove a trusted publisher
(define-public (remove-publisher (publisher principal))
  (begin
    (asserts! (is-admin-caller) ERR-NOT-AUTHORIZED)
    (map-delete trusted-publishers publisher)
    (print {event: "publisher-removed", publisher: publisher})
    (ok true)))

;; ============================================================================
;; PRICE POSTING
;; ============================================================================

;; Post a new price (authorized publishers only)
;; @param price: BTC/USD price in fixed-point (scaled by 1e8)
;; @param reported-at: Block height when price was observed
(define-public (post-price (price uint) (reported-at uint))
  (let (
    (previous-price (var-get current-price))
    (is-first-price (is-eq previous-price u0))
  )
    ;; Authorization check
    (asserts! (is-authorized-publisher tx-sender) ERR-NOT-AUTHORIZED)
    
    ;; System pause check (via access contract)
    (asserts! (not (is-paused)) ERR-SYSTEM-PAUSED)
    
    ;; Circuit breaker check
    (asserts! (not (var-get circuit-breaker-active)) (err u2008))
    
    ;; Validate price is non-zero
    (asserts! (> price u0) ERR-ZERO-PRICE)
    
    ;; Validate price bounds
    (asserts! (and (>= price (var-get min-price)) 
                   (<= price (var-get max-price))) 
              ERR-PRICE-OUT-OF-BOUNDS)
    
    ;; Validate reported-at is not in the future
    (asserts! (<= reported-at block-height) ERR-INVALID-TIMESTAMP)
    
    ;; Check deviation from previous price (skip for first price)
    (asserts! (or is-first-price 
                  (is-within-deviation previous-price price))
              ERR-DEVIATION-TOO-HIGH)
    
    ;; Update price
    (var-set current-price price)
    (var-set price-block block-height)
    (var-set price-timestamp reported-at)
    (var-set last-publisher tx-sender)
    
    ;; Record in history
    (record-price-history price)
    
    (print {
      event: "price-posted",
      price: price,
      block: block-height,
      reported-at: reported-at,
      publisher: tx-sender,
      previous-price: previous-price
    })
    
    (ok price)))

;; Post price with automatic timestamp
(define-public (post-price-now (price uint))
  (post-price price block-height))

;; ============================================================================
;; PRICE READING
;; ============================================================================

;; Get the current BTC/USD price
;; Returns scaled price (multiply by actual BTC amount, divide by PRICE-SCALE)
(define-read-only (get-price)
  (let ((price (var-get current-price)))
    (asserts! (> price u0) ERR-PRICE-NOT-SET)
    (asserts! (is-price-fresh) ERR-PRICE-STALE)
    (ok price)))

;; Get price without staleness check (for informational purposes)
(define-read-only (get-price-unsafe)
  (var-get current-price))

;; Get full price info
(define-read-only (get-price-info)
  {
    price: (var-get current-price),
    block: (var-get price-block),
    timestamp: (var-get price-timestamp),
    publisher: (var-get last-publisher),
    is-fresh: (is-price-fresh),
    staleness-threshold: (var-get staleness-threshold),
    blocks-since-update: (- block-height (var-get price-block))
  })

;; Check if price is fresh (not stale)
(define-read-only (is-price-fresh)
  (let ((blocks-since-update (- block-height (var-get price-block))))
    (<= blocks-since-update (var-get staleness-threshold))))

;; Get blocks until price becomes stale
(define-read-only (blocks-until-stale)
  (let (
    (blocks-since-update (- block-height (var-get price-block)))
    (threshold (var-get staleness-threshold))
  )
    (if (> blocks-since-update threshold)
        u0
        (- threshold blocks-since-update))))

;; ============================================================================
;; TWAP (Time-Weighted Average Price)
;; ============================================================================

;; Record price in history buffer
(define-private (record-price-history (price uint))
  (let ((index (var-get price-history-index)))
    (map-set price-history index {price: price, block: block-height})
    (var-set price-history-index (mod (+ index u1) PRICE-HISTORY-SIZE))
    true))

;; Get simple moving average of recent prices
(define-read-only (get-twap)
  (let (
    (prices (list 
      (default-to {price: u0, block: u0} (map-get? price-history u0))
      (default-to {price: u0, block: u0} (map-get? price-history u1))
      (default-to {price: u0, block: u0} (map-get? price-history u2))
      (default-to {price: u0, block: u0} (map-get? price-history u3))
      (default-to {price: u0, block: u0} (map-get? price-history u4))
      (default-to {price: u0, block: u0} (map-get? price-history u5))
      (default-to {price: u0, block: u0} (map-get? price-history u6))
      (default-to {price: u0, block: u0} (map-get? price-history u7))
      (default-to {price: u0, block: u0} (map-get? price-history u8))
      (default-to {price: u0, block: u0} (map-get? price-history u9))
    ))
    (sum (fold + (map get-price-from-entry prices) u0))
    (count (fold count-non-zero prices u0))
  )
    (if (> count u0)
        (/ sum count)
        u0)))

;; Helper to extract price from entry
(define-private (get-price-from-entry (entry {price: uint, block: uint}))
  (get price entry))

;; Helper to count non-zero entries
(define-private (count-non-zero (entry {price: uint, block: uint}) (acc uint))
  (if (> (get price entry) u0) (+ acc u1) acc))

;; ============================================================================
;; DEVIATION & BOUNDS CHECKING
;; ============================================================================

;; Check if new price is within allowed deviation from previous
(define-read-only (is-within-deviation (old-price uint) (new-price uint))
  (let (
    (max-dev (var-get max-deviation-bps))
    (diff (if (> new-price old-price) 
              (- new-price old-price) 
              (- old-price new-price)))
    (max-allowed-diff (/ (* old-price max-dev) BPS))
  )
    (<= diff max-allowed-diff)))

;; Calculate deviation between two prices (in BPS)
(define-read-only (calculate-deviation (price1 uint) (price2 uint))
  (let (
    (diff (if (> price1 price2) (- price1 price2) (- price2 price1)))
    (base (if (> price1 price2) price2 price1))
  )
    (if (is-eq base u0)
        u0
        (/ (* diff BPS) base))))

;; ============================================================================
;; CIRCUIT BREAKER
;; ============================================================================

;; Trigger circuit breaker (pauses price updates)
(define-public (trigger-circuit-breaker)
  (begin
    (asserts! (or (is-admin-caller) (is-authorized-publisher tx-sender)) ERR-NOT-AUTHORIZED)
    (var-set circuit-breaker-active true)
    (var-set circuit-breaker-block block-height)
    (print {event: "circuit-breaker-triggered", block: block-height, triggerer: tx-sender})
    (ok true)))

;; Reset circuit breaker (admin only)
(define-public (reset-circuit-breaker)
  (begin
    (asserts! (is-admin-caller) ERR-NOT-AUTHORIZED)
    (var-set circuit-breaker-active false)
    (print {event: "circuit-breaker-reset", block: block-height})
    (ok true)))

;; Get circuit breaker status
(define-read-only (get-circuit-breaker-status)
  {
    active: (var-get circuit-breaker-active),
    triggered-at: (var-get circuit-breaker-block)
  })

;; ============================================================================
;; PARAMETER MANAGEMENT
;; ============================================================================

;; Update staleness threshold (admin only)
(define-public (set-staleness-threshold (new-threshold uint))
  (begin
    (asserts! (is-admin-caller) ERR-NOT-AUTHORIZED)
    (asserts! (> new-threshold u0) (err u2009))
    (var-set staleness-threshold new-threshold)
    (print {event: "staleness-threshold-updated", threshold: new-threshold})
    (ok true)))

;; Update price bounds (admin only)
(define-public (set-price-bounds (new-min uint) (new-max uint))
  (begin
    (asserts! (is-admin-caller) ERR-NOT-AUTHORIZED)
    (asserts! (< new-min new-max) (err u2010))
    (var-set min-price new-min)
    (var-set max-price new-max)
    (print {event: "price-bounds-updated", min: new-min, max: new-max})
    (ok true)))

;; Update max deviation (admin only)
(define-public (set-max-deviation (new-deviation uint))
  (begin
    (asserts! (is-admin-caller) ERR-NOT-AUTHORIZED)
    (asserts! (and (> new-deviation u0) (<= new-deviation BPS)) (err u2011))
    (var-set max-deviation-bps new-deviation)
    (print {event: "max-deviation-updated", deviation-bps: new-deviation})
    (ok true)))

;; Get oracle parameters
(define-read-only (get-oracle-params)
  {
    staleness-threshold: (var-get staleness-threshold),
    min-price: (var-get min-price),
    max-price: (var-get max-price),
    max-deviation-bps: (var-get max-deviation-bps),
    price-scale: PRICE-SCALE
  })

;; ============================================================================
;; ACCESS CONTROL HELPERS
;; ============================================================================

;; Check if caller is admin (simplified - in production would call access contract)
(define-private (is-admin-caller)
  (or (is-eq tx-sender (var-get access-contract))
      (is-eq tx-sender tx-sender))) ;; TODO: integrate with access.clar

;; Check if principal is an authorized publisher
(define-read-only (is-authorized-publisher (publisher principal))
  (or (default-to false (map-get? trusted-publishers publisher))
      (is-eq publisher (var-get access-contract))))

;; Check if system is paused (simplified)
(define-private (is-paused)
  false) ;; TODO: integrate with access.clar

;; ============================================================================
;; UTILITY FUNCTIONS
;; ============================================================================

;; Convert USD amount to BTC amount at current price
;; @param usd-amount: USD amount scaled by 1e6
;; @returns: BTC amount in satoshis (1e8)
(define-read-only (usd-to-btc (usd-amount uint))
  (let ((price (var-get current-price)))
    (if (is-eq price u0)
        (err ERR-PRICE-NOT-SET)
        (ok (/ (* usd-amount PRICE-SCALE) price)))))

;; Convert BTC amount to USD amount at current price
;; @param btc-amount: BTC amount in satoshis (1e8)
;; @returns: USD amount scaled by 1e8
(define-read-only (btc-to-usd (btc-amount uint))
  (let ((price (var-get current-price)))
    (if (is-eq price u0)
        (err ERR-PRICE-NOT-SET)
        (ok (/ (* btc-amount price) PRICE-SCALE)))))

;; Get price scale constant
(define-read-only (get-price-scale)
  PRICE-SCALE)

```
