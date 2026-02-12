;; Rental Income Distributor Smart Contract
;; Manages rental income deposits, distribution, and claims.
;; Integrated with multi-sig governance system.

;; ERROR CODES
(define-constant ERR_NOT_AUTHORIZED (err u3001))
(define-constant ERR_PROPERTY_NOT_FOUND (err u3002))
(define-constant ERR_ALREADY_DISTRIBUTED (err u3004))
(define-constant ERR_NOT_DISTRIBUTED (err u3005))
(define-constant ERR_NO_INVESTMENT (err u3006))
(define-constant ERR_ALREADY_CLAIMED (err u3007))
(define-constant ERR_INVALID_INPUT (err u3008))
(define-constant ERR_CONTRACT_PAUSED (err u3009))
(define-constant ERR_AMOUNT_TOO_SMALL (err u3010))
(define-constant ERR_WITHDRAWAL_COOLDOWN (err u3011))
(define-constant ERR_BALANCE_CHECK_FAILED (err u3013))
(define-constant ERR_RENT_AMOUNT_MISMATCH (err u3014))
(define-constant ERR_EXPENSES_TOO_HIGH (err u3015))
(define-constant ERR_ARITHMETIC_OVERFLOW (err u3016))
(define-constant ERR_EMERGENCY_ACTIVE (err u3017))
(define-constant ERR_INVALID_INVESTMENT_DATA (err u3018))

;; CONSTANTS & CONFIGURATION
(define-constant CONTRACT_VERSION u2)
(define-constant SBTC_CONTRACT 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token)
(define-constant MIN_CLAIMABLE_AMOUNT u1000)
(define-constant WITHDRAWAL_COOLDOWN u144)
(define-constant RENT_TOLERANCE_PERCENTAGE u500)
(define-constant MAX_EXPENSES_PERCENTAGE u5000)
(define-constant BASIS_POINTS_SCALE u10000)
(define-constant BLOCKS_PER_DAY u144)
(define-constant MAX_RENT_AMOUNT u1000000000000)
(define-constant MIN_RENT_AMOUNT u1000)
(define-constant EMERGENCY_COOLDOWN u1440)
;; Added max investment validation constant
(define-constant MAX_INVESTMENT_AMOUNT u100000000000000)

;; STATE VARIABLES
(define-data-var platform-wallet principal tx-sender)
(define-data-var contract-paused bool false)
(define-data-var total-platform-fees-collected uint u0)

;; DATA MAPS
(define-map rental-payments
  { property-id: uint, month: uint, year: uint }
  { 
    total-rent-sbtc: uint,
    platform-fee-collected: uint,
    expenses-deducted: uint,
    net-distributable: uint,
    distributed: bool,
    distribution-date: uint,
    deposited-by: principal,
    deposit-date: uint
  })

(define-map period-claims
  { property-id: uint, month: uint, year: uint, investor: principal }
  { 
    gross-amount: uint,
    net-amount: uint,
    platform-fee: uint,
    claimed: bool,
    claim-date: uint
  })

(define-map last-withdrawal 
  { investor: principal } 
  { block-height: uint })

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
    ERR_INVALID_INPUT))

;; Added validation helper for investment data
(define-private (validate-investment-data (user-invested uint) (total-invested uint))
  (begin
    (asserts! (and (<= user-invested MAX_INVESTMENT_AMOUNT)
                   (<= total-invested MAX_INVESTMENT_AMOUNT)
                   (<= user-invested total-invested))
              ERR_INVALID_INVESTMENT_DATA)
    (ok true)))

;; PRIVATE HELPER FUNCTIONS
(define-private (check-withdrawal-cooldown (investor principal))
  (let ((last-wd (map-get? last-withdrawal { investor: investor })))
    (match last-wd
      withdrawal 
        (if (> stacks-block-height (+ (get block-height withdrawal) WITHDRAWAL_COOLDOWN))
          (ok true) 
          ERR_WITHDRAWAL_COOLDOWN)
      (ok true))))

(define-private (validate-rent-amount (property-id uint) (rent-amount uint))
  (let (
    (property (unwrap! (contract-call? .property-registry-v3 get-property property-id) ERR_PROPERTY_NOT_FOUND))
    (expected-rent (get monthly-rent-sbtc property))
    (min-acceptable (unwrap! (safe-sub expected-rent 
                                       (unwrap! (safe-div (unwrap! (safe-mul expected-rent RENT_TOLERANCE_PERCENTAGE) 
                                                                   ERR_ARITHMETIC_OVERFLOW) 
                                                          BASIS_POINTS_SCALE) 
                                                ERR_ARITHMETIC_OVERFLOW)) 
                             ERR_ARITHMETIC_OVERFLOW))
    (max-acceptable (unwrap! (safe-add expected-rent 
                                       (unwrap! (safe-div (unwrap! (safe-mul expected-rent RENT_TOLERANCE_PERCENTAGE) 
                                                                   ERR_ARITHMETIC_OVERFLOW) 
                                                          BASIS_POINTS_SCALE) 
                                                ERR_ARITHMETIC_OVERFLOW)) 
                             ERR_ARITHMETIC_OVERFLOW))
  )
    (ok (and (>= rent-amount min-acceptable) (<= rent-amount max-acceptable)))))

(define-private (validate-expenses (rent-amount uint) (expenses uint))
  (let ((max-expenses (unwrap! (safe-div (unwrap! (safe-mul rent-amount MAX_EXPENSES_PERCENTAGE) 
                                                   ERR_ARITHMETIC_OVERFLOW) 
                                         BASIS_POINTS_SCALE) 
                               ERR_ARITHMETIC_OVERFLOW)))
    (ok (<= expenses max-expenses))))

(define-private (check-contract-balance (required-amount uint))
  (let ((balance (unwrap! (contract-call? SBTC_CONTRACT get-balance (as-contract tx-sender)) 
                          ERR_BALANCE_CHECK_FAILED)))
    (if (>= balance required-amount) (ok true) ERR_BALANCE_CHECK_FAILED)))

(define-private (calculate-platform-fee (rent-amount uint) (fee-rate uint))
  (begin
    (asserts! (and (>= rent-amount MIN_RENT_AMOUNT) (<= rent-amount MAX_RENT_AMOUNT)) ERR_INVALID_INPUT)
    (asserts! (<= fee-rate BASIS_POINTS_SCALE) ERR_INVALID_INPUT)
    
    (let ((fee (unwrap! (safe-div (unwrap! (safe-mul rent-amount fee-rate) ERR_ARITHMETIC_OVERFLOW) 
                                  BASIS_POINTS_SCALE) 
                        ERR_ARITHMETIC_OVERFLOW)))
      (ok fee))))

;; GOVERNANCE INTEGRATION
(define-private (is-governance-admin (caller principal))
  (contract-call? .governance-v3 is-admin caller))

(define-private (is-admin-or-owner (caller principal))
  (or (contract-call? .property-registry-v3 is-contract-owner caller)
      (is-governance-admin caller)))

(define-private (check-emergency-status)
  (let ((emergency-stats (contract-call? .governance-v3 get-emergency-stats)))
    (if (and (> (get last-emergency emergency-stats) u0)
             (< (- stacks-block-height (get last-emergency emergency-stats)) EMERGENCY_COOLDOWN))
      ERR_EMERGENCY_ACTIVE
      (ok true))))

;; READ-ONLY FUNCTIONS
(define-read-only (is-contract-paused) 
  (var-get contract-paused))

(define-read-only (get-platform-wallet) 
  (var-get platform-wallet))

(define-read-only (get-total-platform-fees-collected)
  (var-get total-platform-fees-collected))

(define-read-only (get-rental-payment-info 
    (property-id uint) 
    (month uint) 
    (year uint))
  (map-get? rental-payments { property-id: property-id, month: month, year: year }))

(define-read-only (get-period-claim-info 
    (property-id uint) 
    (month uint) 
    (year uint) 
    (investor principal))
  (map-get? period-claims 
    { property-id: property-id, month: month, year: year, investor: investor }))

(define-read-only (calculate-user-rental-share 
    (property-id uint) 
    (investor principal) 
    (net-distributable uint))
  (let (
    (property-totals (contract-call? .data-store-v3 get-property-investment-totals property-id))
    (user-investment (contract-call? .data-store-v3 get-user-investment property-id investor))
    (total-invested (get total-sbtc-invested property-totals))
    (user-invested (get sbtc-invested user-investment))
  )
    (if (and (> total-invested u0) (> user-invested u0))
      (unwrap-panic (safe-div (unwrap-panic (safe-mul net-distributable user-invested)) total-invested))
      u0)))

(define-read-only (get-claimable-earnings 
    (property-id uint) 
    (month uint) 
    (year uint) 
    (investor principal))
  (let (
    (rental-info (get-rental-payment-info property-id month year))
    (claim-info (get-period-claim-info property-id month year investor))
  )
    (match rental-info
      payment-data 
        (if (and (get distributed payment-data) (is-none claim-info))
          (calculate-user-rental-share property-id investor (get net-distributable payment-data)) 
          u0)
      u0)))

;; ADMIN FUNCTIONS (Governance integrated)
(define-public (pause-contract)
  (begin
    (asserts! (is-admin-or-owner tx-sender) ERR_NOT_AUTHORIZED)
    (var-set contract-paused true)
    (print { e: "paused", by: tx-sender })
    (ok true)))

(define-public (unpause-contract)
  (begin
    (asserts! (is-admin-or-owner tx-sender) ERR_NOT_AUTHORIZED)
    (var-set contract-paused false)
    (print { e: "unpaused", by: tx-sender })
    (ok true)))

(define-public (set-platform-wallet (new-wallet principal))
  (begin
    (asserts! (is-admin-or-owner tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (is-standard new-wallet) ERR_INVALID_INPUT)
    (var-set platform-wallet new-wallet)
    (print { e: "wallet-update", w: new-wallet })
    (ok true)))

;; RENTAL DEPOSIT FUNCTIONS
(define-public (deposit-rental-income 
    (property-id uint) 
    (month uint) 
    (year uint) 
    (rent-amount-sbtc uint) 
    (expenses-this-month uint))
  (let (
    (property (unwrap! (contract-call? .property-registry-v3 get-property property-id) ERR_PROPERTY_NOT_FOUND))
    (period-key { property-id: property-id, month: month, year: year })
    (property-owner (get owner property))
  )
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (unwrap! (check-emergency-status) ERR_EMERGENCY_ACTIVE)
    (asserts! (is-eq tx-sender property-owner) ERR_NOT_AUTHORIZED)
    
    ;; Combined validation
    (asserts! (and (>= month u1)
                   (<= month u12)
                   (>= year u2024)
                   (<= year u2100)
                   (> property-id u0)
                   (>= rent-amount-sbtc MIN_RENT_AMOUNT)
                   (<= rent-amount-sbtc MAX_RENT_AMOUNT)
                   (>= expenses-this-month u0)
                   (is-none (map-get? rental-payments period-key)))
              ERR_INVALID_INPUT)
    
    (unwrap! (validate-rent-amount property-id rent-amount-sbtc) ERR_RENT_AMOUNT_MISMATCH)
    (unwrap! (validate-expenses rent-amount-sbtc expenses-this-month) ERR_EXPENSES_TOO_HIGH)
    
    (let (
      (platform-fee-rate (contract-call? .property-registry-v3 get-platform-fee-rate))
      (platform-fee (unwrap! (calculate-platform-fee rent-amount-sbtc platform-fee-rate) ERR_ARITHMETIC_OVERFLOW))
      (after-expenses (unwrap! (safe-sub rent-amount-sbtc expenses-this-month) ERR_ARITHMETIC_OVERFLOW))
      (net-distributable (unwrap! (safe-sub after-expenses platform-fee) ERR_ARITHMETIC_OVERFLOW))
    )
      ;; STATE UPDATES with safe arithmetic
      (map-set rental-payments period-key
        { 
          total-rent-sbtc: rent-amount-sbtc, 
          platform-fee-collected: platform-fee, 
          expenses-deducted: expenses-this-month,
          net-distributable: net-distributable, 
          distributed: false, 
          distribution-date: u0,
          deposited-by: property-owner, 
          deposit-date: stacks-block-height 
        })
      
      (var-set total-platform-fees-collected 
        (unwrap! (safe-add (var-get total-platform-fees-collected) platform-fee) ERR_ARITHMETIC_OVERFLOW))
      
      ;; TRANSFERS
      (unwrap! (contract-call? SBTC_CONTRACT transfer 
                 rent-amount-sbtc 
                 tx-sender 
                 (as-contract tx-sender) 
                 (some 0x52656e74616c))
               ERR_INVALID_INPUT)
      
      (if (> platform-fee u0)
        (unwrap! (as-contract (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token transfer 
                   platform-fee 
                   (as-contract tx-sender) 
                   (var-get platform-wallet) 
                   (some 0x506c6174666f726d466565)))
                 ERR_INVALID_INPUT)
        true)
      
      ;; Comprehensive event for off-chain analytics
      (print { 
        e: "deposit",
        p: property-id, 
        m: month, 
        y: year, 
        r: rent-amount-sbtc,
        f: platform-fee,
        ex: expenses-this-month,
        n: net-distributable,
        b: stacks-block-height
      })
      (ok true))))

(define-public (deposit-rental-income-override
    (property-id uint) 
    (month uint) 
    (year uint) 
    (rent-amount-sbtc uint) 
    (expenses-this-month uint) 
    (explanation (string-ascii 200)))
  (let (
    (property (unwrap! (contract-call? .property-registry-v3 get-property property-id) ERR_PROPERTY_NOT_FOUND))
    (period-key { property-id: property-id, month: month, year: year })
    (property-owner (get owner property))
  )
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (asserts! (is-admin-or-owner tx-sender) ERR_NOT_AUTHORIZED)
    
    (asserts! (and (>= month u1)
                   (<= month u12)
                   (>= year u2024)
                   (<= year u2100)
                   (> (len explanation) u10)
                   (<= (len explanation) u200)
                   (> property-id u0)
                   (>= rent-amount-sbtc MIN_RENT_AMOUNT)
                   (<= rent-amount-sbtc MAX_RENT_AMOUNT)
                   (>= expenses-this-month u0)
                   (is-none (map-get? rental-payments period-key)))
              ERR_INVALID_INPUT)
    
    (let (
      (platform-fee-rate (contract-call? .property-registry-v3 get-platform-fee-rate))
      (platform-fee (unwrap! (calculate-platform-fee rent-amount-sbtc platform-fee-rate) ERR_ARITHMETIC_OVERFLOW))
      (after-expenses (unwrap! (safe-sub rent-amount-sbtc expenses-this-month) ERR_ARITHMETIC_OVERFLOW))
      (net-distributable (unwrap! (safe-sub after-expenses platform-fee) ERR_ARITHMETIC_OVERFLOW))
    )
      (map-set rental-payments period-key
        { 
          total-rent-sbtc: rent-amount-sbtc, 
          platform-fee-collected: platform-fee, 
          expenses-deducted: expenses-this-month,
          net-distributable: net-distributable, 
          distributed: false, 
          distribution-date: u0,
          deposited-by: property-owner, 
          deposit-date: stacks-block-height 
        })
      
      (var-set total-platform-fees-collected 
        (unwrap! (safe-add (var-get total-platform-fees-collected) platform-fee) ERR_ARITHMETIC_OVERFLOW))
      
      (unwrap! (contract-call? SBTC_CONTRACT transfer 
                 rent-amount-sbtc 
                 property-owner 
                 (as-contract tx-sender) 
                 (some 0x52656e74616c))
               ERR_INVALID_INPUT)
      
      (if (> platform-fee u0)
        (unwrap! (as-contract (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token transfer 
                   platform-fee 
                   (as-contract tx-sender) 
                   (var-get platform-wallet) 
                   (some 0x506c6174666f726d466565)))
                 ERR_INVALID_INPUT)
        true)
      
      (print { 
        e: "override",
        p: property-id, 
        m: month, 
        y: year,
        ex: explanation,
        r: rent-amount-sbtc,
        b: stacks-block-height
      })
      (ok true))))

;; DISTRIBUTION FUNCTIONS
(define-public (distribute-rental-income 
    (property-id uint) 
    (month uint) 
    (year uint))
  (let (
    (period-key { property-id: property-id, month: month, year: year })
    (rental-info (unwrap! (map-get? rental-payments period-key) ERR_PROPERTY_NOT_FOUND))
    (property (unwrap! (contract-call? .property-registry-v3 get-property property-id) ERR_PROPERTY_NOT_FOUND))
  )
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (asserts! (or (is-eq tx-sender (get owner property)) 
                  (is-admin-or-owner tx-sender)) 
              ERR_NOT_AUTHORIZED)
    (asserts! (not (get distributed rental-info)) ERR_ALREADY_DISTRIBUTED)
    
    (map-set rental-payments period-key 
      (merge rental-info { 
        distributed: true, 
        distribution-date: stacks-block-height 
      }))
    
    (print { 
      e: "distribute",
      p: property-id, 
      m: month, 
      y: year,
      b: stacks-block-height
    })
    (ok true)))

;; CLAIM FUNCTIONS
(define-public (claim-rental-earnings 
    (property-id uint) 
    (month uint) 
    (year uint))
  (let (
    (period-key { property-id: property-id, month: month, year: year })
    (rental-info (unwrap! (map-get? rental-payments period-key) ERR_PROPERTY_NOT_FOUND))
    (claim-key { property-id: property-id, month: month, year: year, investor: tx-sender })
    (user-investment (contract-call? .data-store-v3 get-user-investment property-id tx-sender))
    (property-totals (contract-call? .data-store-v3 get-property-investment-totals property-id))
    (total-invested (get total-sbtc-invested property-totals))
    (user-invested (get sbtc-invested user-investment))
  )
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (unwrap! (check-withdrawal-cooldown tx-sender) ERR_WITHDRAWAL_COOLDOWN)
    (unwrap! (check-emergency-status) ERR_EMERGENCY_ACTIVE)
    
    (asserts! (and (>= month u1)
                   (<= month u12)
                   (>= year u2024)
                   (<= year u2100)
                   (get distributed rental-info)
                   (is-none (map-get? period-claims claim-key)))
              ERR_NOT_DISTRIBUTED)
    
    ;; Validate investment data before using in calculations
    (unwrap! (validate-investment-data user-invested total-invested) ERR_INVALID_INVESTMENT_DATA)
    (asserts! (> user-invested u0) ERR_NO_INVESTMENT)
    (asserts! (> total-invested u0) ERR_INVALID_INVESTMENT_DATA)
    
    (let (
      (ownership-pct (unwrap! (safe-div (unwrap! (safe-mul user-invested BASIS_POINTS_SCALE) 
                                                  ERR_ARITHMETIC_OVERFLOW) 
                                        total-invested) 
                              ERR_ARITHMETIC_OVERFLOW))
      (user-share (calculate-user-rental-share property-id tx-sender (get net-distributable rental-info)))
      (user-platform-fee (unwrap! (safe-div (unwrap! (safe-mul (get platform-fee-collected rental-info) ownership-pct) 
                                                       ERR_ARITHMETIC_OVERFLOW) 
                                            BASIS_POINTS_SCALE) 
                                  ERR_ARITHMETIC_OVERFLOW))
      (user-expenses (unwrap! (safe-div (unwrap! (safe-mul (get expenses-deducted rental-info) ownership-pct) 
                                                  ERR_ARITHMETIC_OVERFLOW) 
                                        BASIS_POINTS_SCALE) 
                              ERR_ARITHMETIC_OVERFLOW))
    )
      (asserts! (and (> user-share u0)
                     (>= user-share MIN_CLAIMABLE_AMOUNT))
                ERR_AMOUNT_TOO_SMALL)
      
      (unwrap! (check-contract-balance user-share) ERR_BALANCE_CHECK_FAILED)
      
      ;; STATE UPDATES with safe arithmetic
      (map-set period-claims claim-key
        { 
          gross-amount: (unwrap! (safe-add (unwrap! (safe-add user-share user-platform-fee) ERR_ARITHMETIC_OVERFLOW) 
                                           user-expenses) 
                                 ERR_ARITHMETIC_OVERFLOW),
          net-amount: user-share,
          platform-fee: user-platform-fee, 
          claimed: true, 
          claim-date: stacks-block-height 
        })
      
      (unwrap! (contract-call? .investment-manager-v3 update-user-earnings 
                 tx-sender property-id user-share)
        ERR_NOT_AUTHORIZED)
      
      ;; Capture original claimer before as-contract
      (let ((original-claimer tx-sender))
        (match (as-contract (contract-call? SBTC_CONTRACT transfer 
                 user-share 
                 tx-sender
                 original-claimer
                 (some 0x436c61696d)))
          success-val 
            (begin
              (map-set last-withdrawal 
                { investor: original-claimer } 
                { block-height: stacks-block-height })
              
              ;; Comprehensive event for tax reporting
              (print { 
                e: "claim",
                p: property-id, 
                i: original-claimer,
                m: month, 
                y: year,
                g: (unwrap-panic (safe-add (unwrap-panic (safe-add user-share user-platform-fee)) user-expenses)),
                n: user-share,
                f: user-platform-fee,
                ex: user-expenses,
                b: stacks-block-height
              })
              (ok user-share))
          error-val ERR_INVALID_INPUT)))))

;; EMERGENCY FUNCTIONS (Governance admin only)
(define-public (emergency-withdraw-platform-fees (amount uint))
  (begin
    (asserts! (is-admin-or-owner tx-sender) ERR_NOT_AUTHORIZED)
    
    ;; Check if emergency was declared in governance
    (let ((emergency-stats (contract-call? .governance-v3 get-emergency-stats)))
      (asserts! (and (> (get last-emergency emergency-stats) u0)
                     (<= amount (get max-emergency-amount emergency-stats))
                     (can-trigger-emergency))
                ERR_NOT_AUTHORIZED))
    
    ;; Capture wallet before as-contract
    (let ((emergency-wallet (var-get platform-wallet)))
      (match (as-contract (contract-call? SBTC_CONTRACT transfer 
               amount 
               tx-sender
               emergency-wallet
               (some 0x456d657267656e6379466565)))
        success-val 
          (begin
            ;; Record emergency withdrawal in governance
            (unwrap! (contract-call? .governance-v3 record-emergency-withdrawal amount) ERR_NOT_AUTHORIZED)
            (print { e: "emergency", a: amount, by: tx-sender })
            (ok true))
        error-val ERR_INVALID_INPUT))))

(define-read-only (can-trigger-emergency)
  (contract-call? .governance-v3 can-trigger-emergency))