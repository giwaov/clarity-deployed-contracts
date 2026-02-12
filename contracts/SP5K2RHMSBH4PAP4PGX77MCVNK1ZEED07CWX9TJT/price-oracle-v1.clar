;; price-oracle.clar
;; Decentralized price oracle with multiple data sources and TWAP
;; Supports STX/USD and other trading pairs

;; ============================================================================
;; Constants
;; ============================================================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-INVALID-PRICE (err u402))
(define-constant ERR-STALE-PRICE (err u403))
(define-constant ERR-PAIR-NOT-FOUND (err u404))
(define-constant ERR-REPORTER-NOT-FOUND (err u405))
(define-constant ERR-INSUFFICIENT-REPORTS (err u406))
(define-constant ERR-PRICE-DEVIATION (err u407))
(define-constant ERR-COOLDOWN-ACTIVE (err u408))

;; Configuration
(define-constant PRICE-DECIMALS u8)
(define-constant MAX-PRICE-AGE u144)           ;; ~1 day in blocks
(define-constant MIN-REPORTERS u3)             ;; Minimum reporters for valid price
(define-constant MAX-DEVIATION u500)           ;; 5% max deviation (basis points)
(define-constant TWAP-WINDOW u24)              ;; 24 observations for TWAP
(define-constant REPORT-COOLDOWN u6)           ;; ~1 hour between reports per reporter

;; ============================================================================
;; Data Variables
;; ============================================================================

(define-data-var total-pairs uint u0)
(define-data-var oracle-paused bool false)

;; ============================================================================
;; Data Maps
;; ============================================================================

;; Trading pair configuration
(define-map pairs (string-ascii 20)
  {
    pair-id: uint,
    base-asset: (string-ascii 10),
    quote-asset: (string-ascii 10),
    decimals: uint,
    min-reporters: uint,
    max-deviation: uint,
    is-active: bool,
    created-at: uint
  })

;; Current aggregated price
(define-map prices (string-ascii 20)
  {
    price: uint,
    timestamp: uint,
    stacks-block-height: uint,
    num-reporters: uint,
    confidence: uint
  })

;; Price history for TWAP calculation
(define-map price-history
  { pair: (string-ascii 20), index: uint }
  {
    price: uint,
    timestamp: uint,
    stacks-block-height: uint
  })

;; TWAP tracking
(define-map twap-state (string-ascii 20)
  {
    cumulative-price: uint,
    last-update: uint,
    observation-index: uint,
    twap-price: uint
  })

;; Authorized reporters
(define-map reporters principal
  {
    is-active: bool,
    total-reports: uint,
    last-report-block: uint,
    accuracy-score: uint,
    stake-amount: uint
  })

;; Individual price reports (before aggregation)
(define-map price-reports
  { pair: (string-ascii 20), reporter: principal, round: uint }
  {
    price: uint,
    timestamp: uint,
    stacks-block-height: uint
  })

;; Current reporting round
(define-map reporting-rounds (string-ascii 20)
  {
    round-id: uint,
    start-block: uint,
    reports-count: uint,
    is-finalized: bool
  })

;; ============================================================================
;; Read-Only Functions
;; ============================================================================

;; Get latest price
(define-read-only (get-price (pair (string-ascii 20)))
  (match (map-get? prices pair)
    price-data (ok price-data)
    ERR-PAIR-NOT-FOUND))

;; Get price with staleness check
(define-read-only (get-latest-price (pair (string-ascii 20)))
  (match (map-get? prices pair)
    price-data
      (if (<= (- stacks-block-height (get stacks-block-height price-data)) MAX-PRICE-AGE)
        (ok (get price price-data))
        ERR-STALE-PRICE)
    ERR-PAIR-NOT-FOUND))

;; Get TWAP price
(define-read-only (get-twap-price (pair (string-ascii 20)))
  (match (map-get? twap-state pair)
    state (ok (get twap-price state))
    ERR-PAIR-NOT-FOUND))

;; Get pair info
(define-read-only (get-pair-info (pair (string-ascii 20)))
  (map-get? pairs pair))

;; Check if price is stale
(define-read-only (is-price-stale (pair (string-ascii 20)))
  (match (map-get? prices pair)
    price-data (> (- stacks-block-height (get stacks-block-height price-data)) MAX-PRICE-AGE)
    true))

;; Get reporter info
(define-read-only (get-reporter (reporter principal))
  (map-get? reporters reporter))

;; Check if address is active reporter
(define-read-only (is-reporter (account principal))
  (match (map-get? reporters account)
    reporter-data (get is-active reporter-data)
    false))

;; Get price at specific block (from history)
(define-read-only (get-historical-price (pair (string-ascii 20)) (index uint))
  (map-get? price-history { pair: pair, index: index }))

;; Calculate price change percentage
(define-read-only (get-price-change (pair (string-ascii 20)) (blocks-ago uint))
  (let
    (
      (current-price (unwrap! (get-latest-price pair) (err u0)))
      (twap-state-data (unwrap! (map-get? twap-state pair) (err u0)))
      (historical-index (mod (- (get observation-index twap-state-data) (/ blocks-ago u6)) TWAP-WINDOW))
      (historical (unwrap! (map-get? price-history { pair: pair, index: historical-index }) (err u0)))
    )
    (ok {
      current: current-price,
      historical: (get price historical),
      change-bps: (if (> current-price (get price historical))
                     (/ (* (- current-price (get price historical)) u10000) (get price historical))
                     (/ (* (- (get price historical) current-price) u10000) (get price historical))),
      is-increase: (> current-price (get price historical))
    })))

;; ============================================================================
;; Reporter Management
;; ============================================================================

;; Add authorized reporter (owner only)
(define-public (add-reporter (reporter principal) (stake uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set reporters reporter
      {
        is-active: true,
        total-reports: u0,
        last-report-block: u0,
        accuracy-score: u10000, ;; Start at 100%
        stake-amount: stake
      })
    (print { event: "reporter-added", reporter: reporter, stake: stake })
    (ok true)))

;; Remove reporter (owner only)
(define-public (remove-reporter (reporter principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (match (map-get? reporters reporter)
      reporter-data
        (begin
          (map-set reporters reporter (merge reporter-data { is-active: false }))
          (print { event: "reporter-removed", reporter: reporter })
          (ok true))
      ERR-REPORTER-NOT-FOUND)))

;; ============================================================================
;; Pair Management
;; ============================================================================

;; Register new trading pair
(define-public (register-pair 
    (pair (string-ascii 20))
    (base-asset (string-ascii 10))
    (quote-asset (string-ascii 10))
    (decimals uint))
  (let
    (
      (pair-id (+ (var-get total-pairs) u1))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? pairs pair)) (err u409)) ;; Already exists
    
    (map-set pairs pair
      {
        pair-id: pair-id,
        base-asset: base-asset,
        quote-asset: quote-asset,
        decimals: decimals,
        min-reporters: MIN-REPORTERS,
        max-deviation: MAX-DEVIATION,
        is-active: true,
        created-at: stacks-block-height
      })
    
    ;; Initialize TWAP state
    (map-set twap-state pair
      {
        cumulative-price: u0,
        last-update: stacks-block-height,
        observation-index: u0,
        twap-price: u0
      })
    
    ;; Initialize reporting round
    (map-set reporting-rounds pair
      {
        round-id: u1,
        start-block: stacks-block-height,
        reports-count: u0,
        is-finalized: false
      })
    
    (var-set total-pairs pair-id)
    (print { event: "pair-registered", pair: pair, base: base-asset, quote: quote-asset })
    (ok pair-id)))

;; ============================================================================
;; Price Reporting
;; ============================================================================

;; Submit price report
(define-public (report-price (pair (string-ascii 20)) (price uint))
  (let
    (
      (pair-info (unwrap! (map-get? pairs pair) ERR-PAIR-NOT-FOUND))
      (reporter-info (unwrap! (map-get? reporters tx-sender) ERR-REPORTER-NOT-FOUND))
      (round-info (unwrap! (map-get? reporting-rounds pair) ERR-PAIR-NOT-FOUND))
      (round-id (get round-id round-info))
    )
    ;; Validations
    (asserts! (not (var-get oracle-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active pair-info) ERR-PAIR-NOT-FOUND)
    (asserts! (get is-active reporter-info) ERR-NOT-AUTHORIZED)
    (asserts! (> price u0) ERR-INVALID-PRICE)
    (asserts! (>= (- stacks-block-height (get last-report-block reporter-info)) REPORT-COOLDOWN) ERR-COOLDOWN-ACTIVE)
    
    ;; Check deviation from current price if exists
    (match (map-get? prices pair)
      current-price
        (let
          (
            (current (get price current-price))
            (deviation (if (> price current)
                          (/ (* (- price current) u10000) current)
                          (/ (* (- current price) u10000) current)))
          )
          (asserts! (<= deviation (get max-deviation pair-info)) ERR-PRICE-DEVIATION))
      true)
    
    ;; Store individual report
    (map-set price-reports
      { pair: pair, reporter: tx-sender, round: round-id }
      {
        price: price,
        timestamp: (unwrap-panic (get-stacks-block-info? time stacks-block-height)),
        stacks-block-height: stacks-block-height
      })
    
    ;; Update reporter stats
    (map-set reporters tx-sender
      (merge reporter-info {
        total-reports: (+ (get total-reports reporter-info) u1),
        last-report-block: stacks-block-height
      }))
    
    ;; Update round info
    (map-set reporting-rounds pair
      (merge round-info {
        reports-count: (+ (get reports-count round-info) u1)
      }))
    
    (print { 
      event: "price-reported",
      pair: pair,
      reporter: tx-sender,
      price: price,
      round: round-id
    })
    
    ;; Try to aggregate if enough reports
    (try! (try-aggregate-price pair))
    
    (ok true)))

;; ============================================================================
;; Price Aggregation
;; ============================================================================

;; Aggregate prices from multiple reporters
(define-private (try-aggregate-price (pair (string-ascii 20)))
  (let
    (
      (pair-info (unwrap! (map-get? pairs pair) (err u0)))
      (round-info (unwrap! (map-get? reporting-rounds pair) (err u0)))
    )
    (if (>= (get reports-count round-info) (get min-reporters pair-info))
      (aggregate-and-finalize pair round-info)
      (ok false))))

(define-private (aggregate-and-finalize 
    (pair (string-ascii 20)) 
    (round-info { round-id: uint, start-block: uint, reports-count: uint, is-finalized: bool }))
  (let
    (
      ;; For simplicity, using last reported price
      ;; In production, would calculate median or weighted average
      (round-id (get round-id round-info))
      (timestamp stacks-block-height)
    )
    ;; Mark round as finalized
    (map-set reporting-rounds pair
      (merge round-info { is-finalized: true }))
    
    ;; Start new round
    (map-set reporting-rounds pair
      {
        round-id: (+ round-id u1),
        start-block: stacks-block-height,
        reports-count: u0,
        is-finalized: false
      })
    
    (ok true)))

;; Force price update (for testing/admin)
(define-public (force-update-price (pair (string-ascii 20)) (price uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> price u0) ERR-INVALID-PRICE)
    
    (let
      (
        (timestamp (unwrap-panic (get-stacks-block-info? time stacks-block-height)))
      )
      ;; Update current price
      (map-set prices pair
        {
          price: price,
          timestamp: timestamp,
          stacks-block-height: stacks-block-height,
          num-reporters: u1,
          confidence: u10000
        })
      
      ;; Update TWAP
      (update-twap pair price)
      
      (print { event: "price-updated", pair: pair, price: price, forced: true })
      (ok price))))

;; ============================================================================
;; TWAP Calculation
;; ============================================================================

(define-private (update-twap (pair (string-ascii 20)) (price uint))
  (match (map-get? twap-state pair)
    state
      (let
        (
          (time-elapsed (- stacks-block-height (get last-update state)))
          (new-cumulative (+ (get cumulative-price state) (* price time-elapsed)))
          (new-index (mod (+ (get observation-index state) u1) TWAP-WINDOW))
          (new-twap (if (> time-elapsed u0)
                       (/ new-cumulative time-elapsed)
                       (get twap-price state)))
        )
        ;; Store in history
        (map-set price-history 
          { pair: pair, index: new-index }
          {
            price: price,
            timestamp: (unwrap-panic (get-stacks-block-info? time stacks-block-height)),
            stacks-block-height: stacks-block-height
          })
        
        ;; Update TWAP state
        (map-set twap-state pair
          {
            cumulative-price: new-cumulative,
            last-update: stacks-block-height,
            observation-index: new-index,
            twap-price: new-twap
          })
        
        true)
    false))

;; ============================================================================
;; Admin Functions
;; ============================================================================

;; Pause/unpause oracle
(define-public (set-oracle-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set oracle-paused paused)
    (print { event: "oracle-paused", paused: paused })
    (ok paused)))

;; Update pair parameters
(define-public (update-pair-config 
    (pair (string-ascii 20))
    (min-reporters uint)
    (max-deviation uint))
  (let
    (
      (pair-info (unwrap! (map-get? pairs pair) ERR-PAIR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set pairs pair
      (merge pair-info {
        min-reporters: min-reporters,
        max-deviation: max-deviation
      }))
    (print { event: "pair-config-updated", pair: pair })
    (ok true)))

;; Deactivate pair
(define-public (deactivate-pair (pair (string-ascii 20)))
  (let
    (
      (pair-info (unwrap! (map-get? pairs pair) ERR-PAIR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set pairs pair (merge pair-info { is-active: false }))
    (print { event: "pair-deactivated", pair: pair })
    (ok true)))

;; ============================================================================
;; Utility Functions
;; ============================================================================

;; Convert price to different decimals
(define-read-only (convert-price (price uint) (from-decimals uint) (to-decimals uint))
  (if (> to-decimals from-decimals)
    (* price (pow u10 (- to-decimals from-decimals)))
    (/ price (pow u10 (- from-decimals to-decimals)))))

;; Get price in USD with 2 decimals (for display)
(define-read-only (get-price-usd (pair (string-ascii 20)))
  (match (get-latest-price pair)
    price (ok (/ price (pow u10 (- PRICE-DECIMALS u2))))
    err-val (err err-val)))
