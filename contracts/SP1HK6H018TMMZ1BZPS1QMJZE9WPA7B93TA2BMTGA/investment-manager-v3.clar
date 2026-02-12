;; Investment Manager Smart Contract
;; Manages all investment operations including primary investments, secondary
;; market transactions, refunds, and voting. Integrated with multi-sig governance.

;; ERROR CODES
(define-constant ERR_NOT_AUTHORIZED (err u2001))
(define-constant ERR_PROPERTY_NOT_FOUND (err u2002))
(define-constant ERR_INSUFFICIENT_AMOUNT (err u2003))
(define-constant ERR_PROPERTY_NOT_ACTIVE (err u2004))
(define-constant ERR_TRANSFER_FAILED (err u2005))
(define-constant ERR_INVESTMENT_EXCEEDS_LIMIT (err u2006))
(define-constant ERR_INVALID_INPUT (err u2007))
(define-constant ERR_FUNDING_DEADLINE_PASSED (err u2008))
(define-constant ERR_FUNDING_FAILED (err u2009))
(define-constant ERR_LISTING_NOT_FOUND (err u2010))
(define-constant ERR_INSUFFICIENT_SHARES (err u2011))
(define-constant ERR_NO_INVESTMENT (err u2012))
(define-constant ERR_CONTRACT_PAUSED (err u2013))
(define-constant ERR_INVESTOR_NOT_WHITELISTED (err u2014))
(define-constant ERR_INVESTOR_BLACKLISTED (err u2015))
(define-constant ERR_INVESTMENT_LIMIT_EXCEEDED (err u2016))
(define-constant ERR_TOO_MANY_INVESTORS (err u2017))
(define-constant ERR_AMOUNT_TOO_SMALL (err u2018))
(define-constant ERR_WITHDRAWAL_COOLDOWN (err u2019))
(define-constant ERR_SHARES_NOT_AVAILABLE (err u2021))
(define-constant ERR_ALREADY_CLAIMED (err u2022))
(define-constant ERR_ARITHMETIC_OVERFLOW (err u2023))
(define-constant ERR_PRICE_SLIPPAGE (err u2024))
(define-constant ERR_HOLDING_PERIOD_NOT_MET (err u2025))
(define-constant ERR_BALANCE_CHECK_FAILED (err u2026))
(define-constant ERR_UNAUTHORIZED_CALLER (err u2027))
(define-constant ERR_MAX_PROPERTIES_EXCEEDED (err u2028))
(define-constant ERR_EMERGENCY_ACTIVE (err u2029))

;; CONSTANTS & CONFIGURATION
(define-constant CONTRACT_VERSION u2)
(define-constant SBTC_CONTRACT 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token)
(define-constant MAX_INVESTMENT_PER_USER u100000000)
(define-constant MIN_INVESTMENT_AMOUNT u1000000)
(define-constant WITHDRAWAL_COOLDOWN u144)
(define-constant MIN_HOLDING_PERIOD u1440)
(define-constant MAX_UINT u340282366920938463463374607431768211455)
(define-constant MAX_PROPERTIES_PER_USER u100)
(define-constant BASIS_POINTS_SCALE u10000)
(define-constant PRICE_PRECISION u1000000) ;; 6 decimals for price calculations
(define-constant BLOCKS_PER_DAY u144)
(define-constant EMERGENCY_COOLDOWN u1440)

;; STATE VARIABLES
(define-data-var contract-paused bool false)
(define-data-var investment-counter uint u0)

;; DATA MAPS
(define-map last-withdrawal 
  { investor: principal } 
  { block-height: uint })

(define-map refund-claims
  { property-id: uint, investor: principal }
  { 
    claimed: bool,
    amount-refunded: uint,
    claim-date: uint
  })

;; Safe arithmetic operations
(define-private (safe-add (a uint) (b uint))
  (let ((result (+ a b)))
    (if (and (>= result a) (>= result b))
      (ok result)
      ERR_ARITHMETIC_OVERFLOW)))

(define-private (safe-sub (a uint) (b uint))
  (if (>= a b)
    (ok (- a b))
    ERR_ARITHMETIC_OVERFLOW))

(define-private (safe-mul (a uint) (b uint))
  (if (is-eq b u0)
    (ok u0)
    (let ((result (* a b)))
      (if (is-eq (/ result b) a)
        (ok result)
        ERR_ARITHMETIC_OVERFLOW))))

(define-private (safe-div (a uint) (b uint))
  (if (> b u0)
    (ok (/ a b))
    ERR_ARITHMETIC_OVERFLOW))

;; PRIVATE HELPER FUNCTIONS
(define-private (check-withdrawal-cooldown (investor principal))
  (let ((last-wd (map-get? last-withdrawal { investor: investor })))
    (match last-wd
      withdrawal 
        (if (> stacks-block-height (+ (get block-height withdrawal) WITHDRAWAL_COOLDOWN))
          (ok true) 
          ERR_WITHDRAWAL_COOLDOWN)
      (ok true))))

(define-private (check-holding-period (property-id uint) (investor principal))
  (let ((investment (get-user-investment property-id investor)))
    (if (> stacks-block-height (+ (get investment-date investment) MIN_HOLDING_PERIOD))
      (ok true)
      ERR_HOLDING_PERIOD_NOT_MET)))

(define-private (check-contract-balance (required-amount uint))
  (let ((balance (unwrap! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token get-balance (as-contract tx-sender)) 
                        ERR_BALANCE_CHECK_FAILED)))
    (if (>= balance required-amount) (ok true) ERR_BALANCE_CHECK_FAILED)))

(define-private (is-authorized-contract (caller principal))
  (or (is-eq caller .property-registry-v3)
      (is-eq caller .rental-distributor-v3)))

;; GOVERNANCE INTEGRATION
(define-private (is-governance-admin (caller principal))
  (contract-call? .governance-v3 is-admin caller))

(define-private (check-emergency-status)
  (let ((emergency-stats (contract-call? .governance-v3 get-emergency-stats)))
    (if (and (> (get last-emergency emergency-stats) u0)
             (< (- stacks-block-height (get last-emergency emergency-stats)) EMERGENCY_COOLDOWN))
      ERR_EMERGENCY_ACTIVE
      (ok true))))

;; READ-ONLY FUNCTIONS - Query via data-store
(define-read-only (is-contract-paused) 
  (var-get contract-paused))

(define-read-only (get-user-investment (property-id uint) (investor principal))
  (contract-call? .data-store-v3 get-user-investment property-id investor))

(define-read-only (get-user-ownership-percentage (property-id uint) (investor principal))
  (let (
    (property-totals (contract-call? .data-store-v3 get-property-investment-totals property-id))
    (user-investment (get sbtc-invested (contract-call? .data-store-v3 get-user-investment property-id investor)))
    (total-invested (get total-sbtc-invested property-totals))
  )
    (if (> total-invested u0)
      (ok (/ (* user-investment BASIS_POINTS_SCALE) total-invested))
      (ok u0))))

(define-read-only (get-property-investment-totals (property-id uint))
  (contract-call? .data-store-v3 get-property-investment-totals property-id))

(define-read-only (get-user-portfolio (investor principal))
  (contract-call? .data-store-v3 get-user-portfolio investor))

(define-read-only (get-investment-counter) 
  (var-get investment-counter))

(define-read-only (get-property-investor-count (property-id uint)) 
  (get investor-count (get-property-investment-totals property-id)))

(define-read-only (has-user-invested (property-id uint) (investor principal)) 
  (> (get sbtc-invested (get-user-investment property-id investor)) u0))

(define-read-only (get-refund-claim (property-id uint) (investor principal))
  (map-get? refund-claims { property-id: property-id, investor: investor }))

(define-read-only (get-available-shares (property-id uint) (investor principal))
  (let (
    (user-investment (contract-call? .data-store-v3 get-user-investment property-id investor))
    (total-shares (get sbtc-invested user-investment))
    (listing (contract-call? .property-registry-v3 get-share-listing property-id investor))
  )
    (match listing
      list-data 
        (if (get is-active list-data)
          (ok (- total-shares (get shares-locked list-data)))
          (ok total-shares))
      (ok total-shares))))

(define-read-only (can-list-shares (property-id uint) (investor principal))
  (let ((investment (get-user-investment property-id investor)))
    (and 
      (> (get sbtc-invested investment) u0)
      (> stacks-block-height (+ (get investment-date investment) MIN_HOLDING_PERIOD)))))

;; ADMIN FUNCTIONS (Governance integrated)
(define-public (pause-contract)
  (begin
    (asserts! (or (contract-call? .property-registry-v3 is-contract-owner tx-sender)
                  (is-governance-admin tx-sender))
              ERR_NOT_AUTHORIZED)
    (var-set contract-paused true)
    (print { e: "paused", by: tx-sender, b: stacks-block-height })
    (ok true)))

(define-public (unpause-contract)
  (begin
    (asserts! (or (contract-call? .property-registry-v3 is-contract-owner tx-sender)
                  (is-governance-admin tx-sender))
              ERR_NOT_AUTHORIZED)
    (var-set contract-paused false)
    (print { e: "unpaused", by: tx-sender, b: stacks-block-height })
    (ok true)))

;; INVESTMENT FUNCTIONS
(define-public (invest-in-property (property-id uint) (sbtc-amount uint))
  (let (
    (property (unwrap! (contract-call? .property-registry-v3 get-property property-id) ERR_PROPERTY_NOT_FOUND))
    (funding-info (contract-call? .property-registry-v3 get-funding-info property-id))
    (current-investment (contract-call? .data-store-v3 get-user-investment property-id tx-sender))
    (property-totals (contract-call? .data-store-v3 get-property-investment-totals property-id))
    (user-portfolio (contract-call? .data-store-v3 get-user-portfolio tx-sender))
    (investment-id (unwrap! (safe-add (var-get investment-counter) u1) ERR_ARITHMETIC_OVERFLOW))
  )
    ;; SECURITY CHECKS
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (unwrap! (check-emergency-status) ERR_EMERGENCY_ACTIVE)
    (asserts! (contract-call? .property-registry-v3 is-whitelisted tx-sender) ERR_INVESTOR_NOT_WHITELISTED)
    (asserts! (not (contract-call? .property-registry-v3 is-blacklisted tx-sender)) ERR_INVESTOR_BLACKLISTED)
    
    ;; Combined validation
    (asserts! (and (>= sbtc-amount MIN_INVESTMENT_AMOUNT) (<= sbtc-amount u1000000000)) ERR_INVALID_INPUT)
    (asserts! (and (get is-active property) (get is-verified property)) ERR_PROPERTY_NOT_ACTIVE)
    (asserts! (>= sbtc-amount (get min-investment-sbtc property)) ERR_INSUFFICIENT_AMOUNT)
    (asserts! (and (> (get blocks-remaining funding-info) u0) 
                   (is-eq (get funding-status funding-info) "active")) ERR_FUNDING_DEADLINE_PASSED)
    
    ;; INVESTMENT LIMITS - using safe arithmetic
    (let ((new-user-total (unwrap! (safe-add (get sbtc-invested current-investment) sbtc-amount) ERR_ARITHMETIC_OVERFLOW)))
      (asserts! (<= new-user-total MAX_INVESTMENT_PER_USER) ERR_INVESTMENT_LIMIT_EXCEEDED))
    
    (let ((new-property-count (if (is-eq (get sbtc-invested current-investment) u0)
                                (unwrap! (safe-add (get property-count user-portfolio) u1) ERR_ARITHMETIC_OVERFLOW)
                                (get property-count user-portfolio))))
      (asserts! (<= new-property-count MAX_PROPERTIES_PER_USER) ERR_MAX_PROPERTIES_EXCEEDED))
    
    (asserts! (< (get investor-count property-totals) u100) ERR_TOO_MANY_INVESTORS)
    (asserts! (<= sbtc-amount (unwrap! (safe-sub (get total-value-sbtc property) 
                                                  (get total-sbtc-invested property-totals))
                                       ERR_ARITHMETIC_OVERFLOW))
              ERR_INVESTMENT_EXCEEDS_LIMIT)
    
    ;; TRANSFER FUNDS
    (match (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token transfer 
             sbtc-amount 
             tx-sender 
             (as-contract tx-sender) 
             (some 0x496e7665737474))
      success-val
        (let (
          (new-user-investment (unwrap! (safe-add (get sbtc-invested current-investment) sbtc-amount) ERR_ARITHMETIC_OVERFLOW))
          (new-total-investment (unwrap! (safe-add (get total-sbtc-invested property-totals) sbtc-amount) ERR_ARITHMETIC_OVERFLOW))
          (new-investor-count (if (is-eq (get sbtc-invested current-investment) u0) 
                                (unwrap! (safe-add (get investor-count property-totals) u1) ERR_ARITHMETIC_OVERFLOW)
                                (get investor-count property-totals)))
        )
          ;; UPDATE DATA-STORE-v3
          (unwrap! (contract-call? .data-store-v3 update-user-investment
                     property-id
                     tx-sender
                     new-user-investment
                     (if (is-eq (get sbtc-invested current-investment) u0) 
                       stacks-block-height 
                       (get investment-date current-investment)))
                   ERR_NOT_AUTHORIZED)
          
          (unwrap! (contract-call? .data-store-v3 update-property-totals
                     property-id
                     new-total-investment
                     new-investor-count)
                   ERR_NOT_AUTHORIZED)
          
          (unwrap! (contract-call? .data-store-v3 update-user-portfolio
                     tx-sender
                     (unwrap! (safe-add (get total-sbtc-invested user-portfolio) sbtc-amount) ERR_ARITHMETIC_OVERFLOW)
                     (if (is-eq (get sbtc-invested current-investment) u0) 
                       (unwrap! (safe-add (get property-count user-portfolio) u1) ERR_ARITHMETIC_OVERFLOW)
                       (get property-count user-portfolio))
                     (get total-earnings user-portfolio))
                   ERR_NOT_AUTHORIZED)
          
          (var-set investment-counter investment-id)
          (unwrap! (contract-call? .property-registry-v3 update-property-investment property-id sbtc-amount) 
                   ERR_NOT_AUTHORIZED)
          
          (print { 
            e: "invest",
            id: investment-id,
            p: property-id, 
            i: tx-sender, 
            a: sbtc-amount,
            ut: new-user-investment,
            pt: new-total-investment,
            ic: new-investor-count,
            b: stacks-block-height
          })
          
          (ok investment-id))
      error-val ERR_TRANSFER_FAILED)))


;; SECONDARY MARKET FUNCTIONS
(define-public (create-share-listing
    (property-id uint)
    (shares-for-sale uint)
    (price-per-share uint))
  (let (
    (user-investment (get-user-investment property-id tx-sender))
    (user-shares (get sbtc-invested user-investment))
  )
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (unwrap! (check-emergency-status) ERR_EMERGENCY_ACTIVE)
    (asserts! (and (> shares-for-sale u0) (> price-per-share u0)) ERR_INVALID_INPUT)
    (asserts! (>= user-shares shares-for-sale) ERR_INSUFFICIENT_SHARES)
    (asserts! (> stacks-block-height (+ (get investment-date user-investment) MIN_HOLDING_PERIOD))
              ERR_HOLDING_PERIOD_NOT_MET)
    
    (match (contract-call? .property-registry-v3 list-shares-for-sale 
             property-id 
             shares-for-sale 
             price-per-share)
      success-val
        (begin
          (print { 
            e: "list",
            p: property-id, 
            s: tx-sender, 
            sh: shares-for-sale, 
            pr: price-per-share 
          })
          (ok success-val))
      error-val (err error-val))))

(define-public (purchase-shares 
    (property-id uint) 
    (seller principal) 
    (shares-to-buy uint)
    (max-price-per-share uint))
  (let (
    (listing (unwrap! (contract-call? .property-registry-v3 get-share-listing property-id seller) ERR_LISTING_NOT_FOUND))
    (seller-investment (contract-call? .data-store-v3 get-user-investment property-id seller))
    (buyer-investment (contract-call? .data-store-v3 get-user-investment property-id tx-sender))
    (buyer-portfolio (contract-call? .data-store-v3 get-user-portfolio tx-sender))
    (seller-portfolio (contract-call? .data-store-v3 get-user-portfolio seller))
    (actual-price (get price-per-share listing))
    (investment-id (unwrap! (safe-add (var-get investment-counter) u1) ERR_ARITHMETIC_OVERFLOW))
  )
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (unwrap! (check-emergency-status) ERR_EMERGENCY_ACTIVE)
    (asserts! (and (contract-call? .property-registry-v3 is-whitelisted tx-sender)
                   (not (contract-call? .property-registry-v3 is-blacklisted tx-sender))
                   (not (contract-call? .property-registry-v3 is-blacklisted seller))) 
              ERR_INVESTOR_NOT_WHITELISTED)
    
    (asserts! (and (not (is-eq tx-sender seller))
                   (get is-active listing)
                   (<= actual-price max-price-per-share)
                   (<= shares-to-buy (get shares-for-sale listing))
                   (>= (get sbtc-invested seller-investment) shares-to-buy)
                   (>= (get shares-locked listing) shares-to-buy))
              ERR_INVALID_INPUT)
    
    (let (
      ;; Calculate total cost: (shares * price) / PRICE_PRECISION
      (price-product (unwrap! (safe-mul shares-to-buy actual-price) ERR_ARITHMETIC_OVERFLOW))
      (total-cost (unwrap! (safe-div price-product PRICE_PRECISION) ERR_ARITHMETIC_OVERFLOW))
      (buyer-new-total (unwrap! (safe-add (get sbtc-invested buyer-investment) shares-to-buy) ERR_ARITHMETIC_OVERFLOW))
    )
      (asserts! (<= buyer-new-total MAX_INVESTMENT_PER_USER) ERR_INVESTMENT_LIMIT_EXCEEDED)
      (asserts! (> total-cost u0) ERR_INVALID_INPUT) ;; Ensure cost is non-zero

      (match (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token transfer
               total-cost
               tx-sender
               seller
               (some 0x53686172655472616e73666572))
        success-val
          (let (
            (seller-new-investment (unwrap! (safe-sub (get sbtc-invested seller-investment) shares-to-buy) ERR_ARITHMETIC_OVERFLOW))
            (buyer-was-investor (> (get sbtc-invested buyer-investment) u0))
            (seller-exiting (is-eq seller-new-investment u0))
            (buyer-entering (not buyer-was-investor))
            (property-totals (contract-call? .data-store-v3 get-property-investment-totals property-id))
            (net-investor-change (if seller-exiting
                                   (if buyer-entering 0 -1)
                                   (if buyer-entering 1 0)))
            (new-investor-count (if (< net-investor-change 0)
                                  (unwrap! (safe-sub (get investor-count property-totals) u1) ERR_ARITHMETIC_OVERFLOW)
                                  (if (> net-investor-change 0)
                                    (unwrap! (safe-add (get investor-count property-totals) u1) ERR_ARITHMETIC_OVERFLOW)
                                    (get investor-count property-totals))))
          )
            ;; UPDATE DATA-STORE-v3 with safe arithmetic
            (unwrap! (contract-call? .data-store-v3 update-user-investment
                       property-id
                       seller
                       seller-new-investment
                       (get investment-date seller-investment))
                     ERR_NOT_AUTHORIZED)
            
            (unwrap! (contract-call? .data-store-v3 update-user-portfolio
                       seller
                       (unwrap! (safe-sub (get total-sbtc-invested seller-portfolio) shares-to-buy) ERR_ARITHMETIC_OVERFLOW)
                       (if seller-exiting
                         (unwrap! (safe-sub (get property-count seller-portfolio) u1) ERR_ARITHMETIC_OVERFLOW)
                         (get property-count seller-portfolio))
                       (get total-earnings seller-portfolio))
                     ERR_NOT_AUTHORIZED)
            
            (unwrap! (contract-call? .data-store-v3 update-user-investment
                       property-id
                       tx-sender
                       (unwrap! (safe-add (get sbtc-invested buyer-investment) shares-to-buy) ERR_ARITHMETIC_OVERFLOW)
                       (if buyer-entering 
                         stacks-block-height 
                         (get investment-date buyer-investment)))
                     ERR_NOT_AUTHORIZED)
            
            (unwrap! (contract-call? .data-store-v3 update-user-portfolio
                       tx-sender
                       (unwrap! (safe-add (get total-sbtc-invested buyer-portfolio) shares-to-buy) ERR_ARITHMETIC_OVERFLOW)
                       (if buyer-entering
                         (unwrap! (safe-add (get property-count buyer-portfolio) u1) ERR_ARITHMETIC_OVERFLOW)
                         (get property-count buyer-portfolio))
                       (get total-earnings buyer-portfolio))
                     ERR_NOT_AUTHORIZED)
            
            (unwrap! (contract-call? .data-store-v3 update-property-totals
                       property-id
                       (get total-sbtc-invested property-totals)
                       new-investor-count)
                     ERR_NOT_AUTHORIZED)
            
            (var-set investment-counter investment-id)
            (unwrap! (contract-call? .property-registry-v3 update-listing-after-purchase 
                       property-id seller shares-to-buy) 
                     ERR_NOT_AUTHORIZED)
            
            (print { 
              e: "buy",
              id: investment-id,
              p: property-id, 
              b: tx-sender, 
              s: seller, 
              sh: shares-to-buy, 
              pr: actual-price,
              tc: total-cost
            })
            
            (ok investment-id))
        error-val ERR_TRANSFER_FAILED))))

;; EARNINGS & REFUND FUNCTIONS
(define-public (update-user-earnings 
    (investor principal) 
    (property-id uint) 
    (earnings-amount uint))
  (let ((current-portfolio (contract-call? .data-store-v3 get-user-portfolio investor)))
    ;; Use contract-caller for authorization
    (asserts! (or (is-eq contract-caller .property-registry-v3)
                  (is-eq contract-caller .rental-distributor-v3))
              ERR_UNAUTHORIZED_CALLER)
    (asserts! (and (is-standard investor) (> property-id u0) (<= earnings-amount u1000000000)) ERR_INVALID_INPUT)
    
    (let ((new-total-earnings (unwrap! (safe-add (get total-earnings current-portfolio) earnings-amount) ERR_ARITHMETIC_OVERFLOW)))
      (unwrap! (contract-call? .data-store-v3 update-user-portfolio
                 investor
                 (get total-sbtc-invested current-portfolio)
                 (get property-count current-portfolio)
                 new-total-earnings)
               ERR_NOT_AUTHORIZED)
      
      (print { 
        e: "earn",
        i: investor, 
        p: property-id, 
        a: earnings-amount 
      })
      (ok true))))

(define-public (claim-refund-for-failed-property (property-id uint))
(let (
  (property (unwrap! (contract-call? .property-registry-v3 get-property property-id) ERR_PROPERTY_NOT_FOUND))
  (funding-info (contract-call? .property-registry-v3 get-funding-info property-id))
  (user-investment (contract-call? .data-store-v3 get-user-investment property-id tx-sender))
  (refund-amount (get sbtc-invested user-investment))
  (investment-id (unwrap! (safe-add (var-get investment-counter) u1) ERR_ARITHMETIC_OVERFLOW))
  (existing-claim (get-refund-claim property-id tx-sender))
  ;; Capture the original claimer before as-contract
  (original-claimer tx-sender)
)
  ;; ALL CHECKS FIRST - Before any state changes
  (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
  (asserts! (is-none existing-claim) ERR_ALREADY_CLAIMED)
  (unwrap! (check-withdrawal-cooldown tx-sender) ERR_WITHDRAWAL_COOLDOWN)
  (asserts! (> refund-amount u0) ERR_INSUFFICIENT_AMOUNT)
  (asserts! (is-eq (get funding-status funding-info) "failed") ERR_FUNDING_FAILED)
  (unwrap! (check-contract-balance refund-amount) ERR_BALANCE_CHECK_FAILED)
    
    ;; TRANSFER FIRST
    (unwrap! (as-contract (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token transfer 
            refund-amount 
            tx-sender              ;; Contract (sender)
            original-claimer       ;; User (recipient)
            (some 0x526566756e64)))
            ERR_TRANSFER_FAILED)
    
    ;; STATE UPDATES - Only executed after successful transfer
    (unwrap! (contract-call? .data-store-v3 update-user-investment
               property-id
               original-claimer
               u0
               (get investment-date user-investment))
             ERR_NOT_AUTHORIZED)
    
    (let (
      (current-portfolio (contract-call? .data-store-v3 get-user-portfolio original-claimer))
      (property-totals (contract-call? .data-store-v3 get-property-investment-totals property-id))
    )
      (unwrap! (contract-call? .data-store-v3 update-user-portfolio
                 original-claimer
                 (unwrap! (safe-sub (get total-sbtc-invested current-portfolio) refund-amount) ERR_ARITHMETIC_OVERFLOW)
                 (unwrap! (safe-sub (get property-count current-portfolio) u1) ERR_ARITHMETIC_OVERFLOW)
                 (get total-earnings current-portfolio))
               ERR_NOT_AUTHORIZED)
      
      (unwrap! (contract-call? .data-store-v3 update-property-totals
                 property-id
                 (unwrap! (safe-sub (get total-sbtc-invested property-totals) refund-amount) ERR_ARITHMETIC_OVERFLOW)
                 (unwrap! (safe-sub (get investor-count property-totals) u1) ERR_ARITHMETIC_OVERFLOW))
               ERR_NOT_AUTHORIZED))
    
    ;; Mark refund as claimed
    (map-set refund-claims 
      { property-id: property-id, investor: original-claimer }
      { 
        claimed: true, 
        amount-refunded: refund-amount, 
        claim-date: stacks-block-height 
      })
    
    ;; Update withdrawal tracking
    (map-set last-withdrawal 
      { investor: original-claimer } 
      { block-height: stacks-block-height })
    
    ;; Update investment counter
    (var-set investment-counter investment-id)
    
    (print { 
      e: "refund",
      id: investment-id,
      p: property-id, 
      i: original-claimer, 
      a: refund-amount 
    })
    
    (ok refund-amount)))

;; GOVERNANCE FUNCTIONS
(define-public (cast-vote-on-proposal 
    (proposal-id uint) 
    (property-id uint) 
    (vote-for bool))
  (let ((voting-power (unwrap! (get-user-ownership-percentage property-id tx-sender) ERR_NO_INVESTMENT)))
    (asserts! (and (not (var-get contract-paused)) (> voting-power u0)) ERR_NO_INVESTMENT)
    
    (match (contract-call? .property-registry-v3 record-vote 
             proposal-id 
             tx-sender 
             vote-for 
             voting-power)
      success-val
        (begin
          (print { 
            e: "vote",
            pr: proposal-id, 
            p: property-id, 
            v: tx-sender, 
            f: vote-for, 
            w: voting-power 
          })
          (ok success-val))
      error-val (err error-val))))

;; EMERGENCY FUNCTIONS (Governance admin only)
(define-public (emergency-withdraw (recipient principal) (amount uint))
  (begin
    (asserts! (and (or (contract-call? .property-registry-v3 is-contract-owner tx-sender)
                       (is-governance-admin tx-sender))
                   (is-standard recipient)
                   (> amount u0))
              ERR_NOT_AUTHORIZED)
    
    ;; Check if emergency was declared in governance
    (let ((emergency-stats (contract-call? .governance-v3 get-emergency-stats)))
      (asserts! (and (> (get last-emergency emergency-stats) u0)
                     (<= amount (get max-emergency-amount emergency-stats))
                     (can-trigger-emergency))
                ERR_NOT_AUTHORIZED))
    
    ;; Transfer funds
    (unwrap! (as-contract (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token transfer 
           amount 
           tx-sender
           recipient
           (some 0x456d6572676e6379)))
           ERR_TRANSFER_FAILED)
    
    ;; Record emergency withdrawal in governance
    (unwrap! (contract-call? .governance-v3 record-emergency-withdrawal amount) ERR_NOT_AUTHORIZED)
    (print { 
      e: "emergency",
      r: recipient, 
      a: amount, 
      by: tx-sender 
    })
    (ok true)))

(define-read-only (can-trigger-emergency)
  (contract-call? .governance-v3 can-trigger-emergency))