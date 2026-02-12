;; Property Registry Smart Contract

;; CONTRACT OWNER
(define-constant CONTRACT_OWNER tx-sender)

;; ERROR CODES
(define-constant ERR_NOT_AUTHORIZED (err u1001))
(define-constant ERR_PROPERTY_NOT_FOUND (err u1002))
(define-constant ERR_INVALID_AMOUNT (err u1003))
(define-constant ERR_PROPERTY_ALREADY_EXISTS (err u1004))
(define-constant ERR_INVALID_INPUT (err u1005))
(define-constant ERR_PROPERTY_VALUE_TOO_HIGH (err u1006))
(define-constant ERR_RENT_YIELD_UNREALISTIC (err u1007))
(define-constant ERR_ALREADY_VOTED (err u1009))
(define-constant ERR_PROPOSAL_EXPIRED (err u1010))
(define-constant ERR_NO_INVESTMENT (err u1011))
(define-constant ERR_CONTRACT_PAUSED (err u1012))
(define-constant ERR_INVESTOR_NOT_WHITELISTED (err u1013))
(define-constant ERR_INVESTOR_BLACKLISTED (err u1014))
(define-constant ERR_TOO_MANY_INVESTORS (err u1015))
(define-constant ERR_PROPOSAL_NOT_PASSED (err u1018))
(define-constant ERR_PROPOSAL_ALREADY_EXECUTED (err u1019))
(define-constant ERR_LISTING_NOT_FOUND (err u1020))
(define-constant ERR_SHARES_NOT_AVAILABLE (err u1021))
(define-constant ERR_PROPERTY_NOT_LIQUIDATED (err u1022))
(define-constant ERR_INSUFFICIENT_VOTES (err u1023))
(define-constant ERR_FUNDING_INCOMPLETE (err u1024))
(define-constant ERR_ALREADY_ACTIVATED (err u1025))
(define-constant ERR_FUNDS_ALREADY_RELEASED (err u1026))
(define-constant ERR_INSUFFICIENT_SHARES (err u1027))
(define-constant ERR_ARITHMETIC_OVERFLOW (err u1028))
(define-constant ERR_DEADLINE_ALREADY_CHECKED (err u1029))
(define-constant ERR_UNAUTHORIZED_CALLER (err u1030))
(define-constant ERR_BALANCE_CHECK_FAILED (err u1031))
(define-constant ERR_LIQUIDATION_TOO_LOW (err u1032))
(define-constant ERR_GOVERNANCE_ACTION_NOT_EXECUTED (err u1033))
(define-constant ERR_VERIFICATION_SCORE_TOO_LOW (err u1034))

;; CONSTANTS & CONFIGURATION
(define-constant CONTRACT_VERSION u2)
(define-constant MAX_PROPERTY_VALUE u1000000000)
(define-constant MIN_PROPERTY_VALUE u10000000)
(define-constant TARGET_ANNUAL_YIELD u2000)
(define-constant MIN_FUNDING_THRESHOLD u5000)
(define-constant MAX_FUNDING_THRESHOLD u10000)
(define-constant VOTING_PERIOD u1440)
(define-constant MAX_INVESTORS_PER_PROPERTY u100)
(define-constant PROPOSAL_EXECUTION_DELAY u144)
(define-constant PROPOSAL_EXPIRY_PERIOD u8640)
(define-constant QUORUM_PERCENTAGE u3000)
(define-constant MIN_PARTICIPATION_PCT u5000)
(define-constant FUNDS_RELEASE_DELAY u1440)
(define-constant MIN_LIQUIDATION_PCT u5000)
(define-constant SBTC_CONTRACT 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token)
(define-constant BASIS_POINTS_SCALE u10000)
(define-constant BLOCKS_PER_DAY u144)
(define-constant MIN_VERIFICATION_SCORE u85)

;; STATE VARIABLES
(define-data-var property-counter uint u0)
(define-data-var platform-fee-rate uint u300)
(define-data-var proposal-counter uint u0)
(define-data-var contract-paused bool false)

;; DATA MAPS
(define-map properties
  { property-id: uint }
  { 
    owner: principal,
    title: (string-ascii 100),
    location: (string-ascii 100),
    total-value-sbtc: uint,
    total-invested-sbtc: uint,
    monthly-rent-sbtc: uint,
    min-investment-sbtc: uint,
    is-verified: bool,
    is-active: bool,
    created-at: uint,
    funding-deadline: uint,
    funding-threshold: uint,
    funding-status: (string-ascii 20),
    is-liquidated: bool,
    liquidation-value: uint,
    funds-released: bool,
    funds-release-date: uint,
    deadline-checked: bool,
    verification-score: uint,
    verified-by-governance: bool
  })

(define-map whitelisted-investors principal bool)
(define-map blacklisted-investors principal bool)

(define-map governance-proposals
  { proposal-id: uint }
  { 
    property-id: uint,
    proposal-type: (string-ascii 50),
    description: (string-ascii 300),
    proposed-by: principal,
    created-at: uint,
    voting-deadline: uint,
    votes-for: uint,
    votes-against: uint,
    total-voting-power: uint,
    executed: bool,
    execution-block: uint,
    new-value: uint,
    new-principal: (optional principal),
    snapshot-total-investment: uint
  })

(define-map proposal-votes
  { proposal-id: uint, voter: principal }
  { 
    vote-weight: uint,
    vote-for: bool
  })

(define-map share-listings
  { property-id: uint, seller: principal }
  { 
    shares-for-sale: uint,
    price-per-share: uint,
    is-active: bool,
    shares-locked: uint,
    listing-date: uint,
    version: uint
  })

(define-map liquidation-distributions
  { property-id: uint }
  {
    total-distributed: uint,
    distribution-complete: bool,
    distribution-date: uint
  })

(define-map liquidation-claims
  { property-id: uint, investor: principal }
  {
    claimed: bool,
    amount-claimed: uint,
    claim-date: uint
  })

(define-map executed-governance-actions
  { action-id: uint }
  {
    executed-at: uint,
    executed-by: principal,
    property-affected: (optional uint),
    investor-affected: (optional principal)
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
    ERR_INVALID_INPUT))

;; Use data-store-v3 for investment data
(define-read-only (get-property-investment-totals-public (property-id uint))
  (contract-call? .data-store-v3 get-property-investment-totals property-id))

(define-read-only (get-user-investment-public (property-id uint) (investor principal))
  (contract-call? .data-store-v3 get-user-investment property-id investor))

;; PRIVATE HELPER FUNCTIONS
(define-private (is-valid-property-value (value uint)) 
  (and (>= value MIN_PROPERTY_VALUE) (<= value MAX_PROPERTY_VALUE)))

(define-private (calculate-target-monthly-rent (property-value uint)) 
  (unwrap-panic (safe-div (unwrap-panic (safe-mul property-value TARGET_ANNUAL_YIELD)) 
                          (unwrap-panic (safe-mul u12 BASIS_POINTS_SCALE)))))

(define-private (is-realistic-rent-yield (monthly-rent uint) (property-value uint))
  (let ((annual-yield (unwrap-panic (safe-div (unwrap-panic (safe-mul (unwrap-panic (safe-mul monthly-rent u12)) BASIS_POINTS_SCALE)) 
                                               property-value))))
    (and (>= annual-yield u1500) (<= annual-yield u2500))))

(define-private (is-authorized-contract (caller principal))
  (or (is-eq caller .investment-manager-v3)
      (is-eq caller .rental-distributor-v3)))

;; GOVERNANCE HELPERS
(define-private (is-governance-admin (caller principal))
  (contract-call? .governance-v3 is-admin caller))

(define-private (is-admin-or-owner (caller principal))
  (or (is-eq caller CONTRACT_OWNER)
      (is-governance-admin caller)))

(define-private (check-emergency-status)
  (let ((emergency-stats (contract-call? .governance-v3 get-emergency-stats)))
    (if (and (> (get last-emergency emergency-stats) u0)
             (< (- stacks-block-height (get last-emergency emergency-stats)) u1440))
      ERR_CONTRACT_PAUSED
      (ok true))))

;; READ-ONLY FUNCTIONS
(define-read-only (is-contract-paused) 
  (var-get contract-paused))

(define-read-only (get-property (property-id uint)) 
  (map-get? properties { property-id: property-id }))

(define-read-only (get-property-count) 
  (var-get property-counter))

(define-read-only (get-platform-fee-rate) 
  (var-get platform-fee-rate))

(define-read-only (is-contract-owner (user principal)) 
  (is-eq user CONTRACT_OWNER))

(define-read-only (is-whitelisted (investor principal)) 
  (default-to false (map-get? whitelisted-investors investor)))

(define-read-only (is-blacklisted (investor principal)) 
  (default-to false (map-get? blacklisted-investors investor)))

(define-read-only (get-proposal (proposal-id uint)) 
  (map-get? governance-proposals { proposal-id: proposal-id }))

(define-read-only (get-user-vote (proposal-id uint) (voter principal)) 
  (map-get? proposal-votes { proposal-id: proposal-id, voter: voter }))

(define-read-only (get-share-listing (property-id uint) (seller principal)) 
  (map-get? share-listings { property-id: property-id, seller: seller }))

(define-read-only (get-executed-governance-action (action-id uint))
  (map-get? executed-governance-actions { action-id: action-id }))

(define-read-only (get-funding-info (property-id uint))
  (let (
    (property (unwrap! 
      (get-property property-id) 
      { funding-deadline: u0, funding-threshold: u0, funding-status: "not-found", 
        current-funding: u0, funding-percentage: u0, blocks-remaining: u0 }))
  )
    (let (
      (current-funding (get total-invested-sbtc property))
      (funding-percentage (if (> (get total-value-sbtc property) u0)
                            (unwrap-panic (safe-div (unwrap-panic (safe-mul current-funding BASIS_POINTS_SCALE)) 
                                                     (get total-value-sbtc property)))
                            u0))
      (blocks-remaining (if (> (get funding-deadline property) stacks-block-height)
                          (- (get funding-deadline property) stacks-block-height) 
                          u0))
    )
      { 
        funding-deadline: (get funding-deadline property), 
        funding-threshold: (get funding-threshold property),
        funding-status: (get funding-status property), 
        current-funding: current-funding,
        funding-percentage: funding-percentage, 
        blocks-remaining: blocks-remaining 
      })))

(define-read-only (can-execute-proposal (proposal-id uint))
  (let ((proposal (unwrap! (get-proposal proposal-id) (ok false))))
    (let (
      (snapshot-investment (get snapshot-total-investment proposal))
      (required-quorum (unwrap-panic (safe-div (unwrap-panic (safe-mul snapshot-investment QUORUM_PERCENTAGE)) BASIS_POINTS_SCALE)))
      (required-participation (unwrap-panic (safe-div (unwrap-panic (safe-mul snapshot-investment MIN_PARTICIPATION_PCT)) BASIS_POINTS_SCALE)))
      (voting-ended (> stacks-block-height (get voting-deadline proposal)))
      (execution-delay-passed (> stacks-block-height (+ (get voting-deadline proposal) PROPOSAL_EXECUTION_DELAY)))
      (not-expired (< stacks-block-height (+ (get voting-deadline proposal) PROPOSAL_EXPIRY_PERIOD)))
      (has-enough-votes (and 
        (> (get votes-for proposal) (get votes-against proposal))
        (or (is-eq snapshot-investment u0)
            (and (>= (get total-voting-power proposal) required-quorum)
                 (>= (get total-voting-power proposal) required-participation)))))
    )
      (ok (and 
        (not (get executed proposal))
        voting-ended
        execution-delay-passed
        not-expired
        has-enough-votes)))))

(define-read-only (get-available-shares-for-listing (property-id uint) (seller principal))
  (let ((listing (get-share-listing property-id seller)))
    (match listing
      list-data (ok (get shares-locked list-data))
      (ok u0))))

;; ADMIN FUNCTIONS
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

;; GOVERNANCE INTEGRATED FUNCTIONS
(define-public (execute-governance-action (action-id uint))
  (let (
    (action (unwrap! (contract-call? .governance-v3 execute-action action-id) ERR_GOVERNANCE_ACTION_NOT_EXECUTED))
  )
    (asserts! (is-governance-admin tx-sender) ERR_NOT_AUTHORIZED)
    
    (let (
      (action-type (get action-type action))
      (target-contract (get target-contract action))
    )
      (asserts! (is-eq target-contract "property-registry-v3") ERR_INVALID_INPUT)
      
      (let ((result
        (if (is-eq action-type "verify-property")
          (execute-verify-property-action action)
          (if (is-eq action-type "update-platform-fee")
            (execute-fee-update-action action)
            (if (is-eq action-type "whitelist-investor")
              (execute-whitelist-action action)
              (if (is-eq action-type "blacklist-investor")
                (execute-blacklist-action action)
                ERR_INVALID_INPUT))))))
        
        (unwrap! result ERR_INVALID_INPUT)
        
        (map-set executed-governance-actions
          { action-id: action-id }
          {
            executed-at: stacks-block-height,
            executed-by: tx-sender,
            property-affected: (some (get value-1 action)),
            investor-affected: (get target-principal action)
          })
        
        (print { e: "gov-action-executed", id: action-id, type: action-type })
        (ok true)))))

(define-private (execute-verify-property-action (action {
    action-type: (string-ascii 50),
    description: (string-ascii 300),
    target-contract: (string-ascii 50),
    target-principal: (optional principal),
    value-1: uint,
    value-2: uint,
    value-3: uint,
    string-param: (optional (string-ascii 200)),
    created-at: uint,
    created-by: principal,
    executable-after: uint,
    expires-at: uint,
    executed: bool,
    executed-at: uint,
    approvals: (list 10 principal),
    approval-count: uint
  }))
  (let (
    (property-id (get value-1 action))
    (property (unwrap! (get-property property-id) ERR_PROPERTY_NOT_FOUND))
    (verification-data (contract-call? .governance-v3 get-property-verification-score property-id))
  )
    (match verification-data
      score-data
        (begin
          (asserts! (>= (get total-score score-data) MIN_VERIFICATION_SCORE) ERR_VERIFICATION_SCORE_TOO_LOW)
          (asserts! (not (get is-verified property)) ERR_PROPERTY_ALREADY_EXISTS)
          
          (map-set properties 
            { property-id: property-id }
            (merge property { 
              is-verified: true, 
              is-active: true, 
              funding-status: "active",
              verification-score: (get total-score score-data),
              verified-by-governance: true
            }))
          
          (print { e: "verify", p: property-id, score: (get total-score score-data) })
          (ok true))
      ERR_VERIFICATION_SCORE_TOO_LOW)))

(define-private (execute-fee-update-action (action {
    action-type: (string-ascii 50),
    description: (string-ascii 300),
    target-contract: (string-ascii 50),
    target-principal: (optional principal),
    value-1: uint,
    value-2: uint,
    value-3: uint,
    string-param: (optional (string-ascii 200)),
    created-at: uint,
    created-by: principal,
    executable-after: uint,
    expires-at: uint,
    executed: bool,
    executed-at: uint,
    approvals: (list 10 principal),
    approval-count: uint
  }))
  (let ((new-rate (get value-1 action)))
    (asserts! (<= new-rate u1000) ERR_INVALID_AMOUNT)
    (var-set platform-fee-rate new-rate)
    (print { e: "fee-update", r: new-rate })
    (ok true)))

(define-private (execute-whitelist-action (action {
    action-type: (string-ascii 50),
    description: (string-ascii 300),
    target-contract: (string-ascii 50),
    target-principal: (optional principal),
    value-1: uint,
    value-2: uint,
    value-3: uint,
    string-param: (optional (string-ascii 200)),
    created-at: uint,
    created-by: principal,
    executable-after: uint,
    expires-at: uint,
    executed: bool,
    executed-at: uint,
    approvals: (list 10 principal),
    approval-count: uint
  }))
  (let ((investor (unwrap! (get target-principal action) ERR_INVALID_INPUT)))
    (asserts! (is-standard investor) ERR_INVALID_INPUT)
    (map-set whitelisted-investors investor true)
    (print { e: "whitelist", i: investor })
    (ok true)))

(define-private (execute-blacklist-action (action {
    action-type: (string-ascii 50),
    description: (string-ascii 300),
    target-contract: (string-ascii 50),
    target-principal: (optional principal),
    value-1: uint,
    value-2: uint,
    value-3: uint,
    string-param: (optional (string-ascii 200)),
    created-at: uint,
    created-by: principal,
    executable-after: uint,
    expires-at: uint,
    executed: bool,
    executed-at: uint,
    approvals: (list 10 principal),
    approval-count: uint
  }))
  (let ((investor (unwrap! (get target-principal action) ERR_INVALID_INPUT)))
    (asserts! (is-standard investor) ERR_INVALID_INPUT)
    (map-set blacklisted-investors investor true)
    (map-set whitelisted-investors investor false)
    (print { e: "blacklist", i: investor })
    (ok true)))

;; Legacy admin functions
(define-public (whitelist-investor (investor principal))
  (begin
    (asserts! (is-admin-or-owner tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (is-standard investor) ERR_INVALID_INPUT)
    (map-set whitelisted-investors investor true)
    (print { e: "whitelist", i: investor })
    (ok true)))

(define-public (blacklist-investor (investor principal))
  (begin
    (asserts! (is-admin-or-owner tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (is-standard investor) ERR_INVALID_INPUT)
    (map-set blacklisted-investors investor true)
    (print { e: "blacklist", i: investor })
    (ok true)))

(define-public (update-platform-fee-rate (new-rate uint))
  (begin
    (asserts! (is-admin-or-owner tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-rate u1000) ERR_INVALID_AMOUNT)
    (var-set platform-fee-rate new-rate)
    (print { e: "fee-update", r: new-rate })
    (ok true)))

;; PROPERTY MANAGEMENT
(define-public (submit-property 
    (title (string-ascii 100)) 
    (location (string-ascii 100)) 
    (total-value-sbtc uint)
    (monthly-rent-sbtc uint) 
    (min-investment-sbtc uint) 
    (funding-days uint) 
    (funding-threshold uint))
  (begin
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (unwrap! (check-emergency-status) ERR_CONTRACT_PAUSED)
    
    (asserts! (and (> funding-days u0) (<= funding-days u90)) ERR_INVALID_INPUT)
    (asserts! (is-valid-property-value total-value-sbtc) ERR_PROPERTY_VALUE_TOO_HIGH)
    
    (asserts! (and (>= min-investment-sbtc u1000000)
                   (<= min-investment-sbtc total-value-sbtc)
                   (> monthly-rent-sbtc u0)
                   (>= funding-threshold MIN_FUNDING_THRESHOLD)
                   (<= funding-threshold MAX_FUNDING_THRESHOLD)
                   (>= (len title) u1)
                   (<= (len title) u100)
                   (>= (len location) u1)
                   (<= (len location) u100)
                   (is-realistic-rent-yield monthly-rent-sbtc total-value-sbtc))
              ERR_INVALID_INPUT)
    
    (let (
      (property-id (+ (var-get property-counter) u1))
      (funding-deadline (+ stacks-block-height (unwrap! (safe-mul funding-days BLOCKS_PER_DAY) ERR_ARITHMETIC_OVERFLOW)))
    )
      (map-set properties 
        { property-id: property-id }
        { 
          owner: tx-sender, 
          title: title, 
          location: location, 
          total-value-sbtc: total-value-sbtc, 
          total-invested-sbtc: u0, 
          monthly-rent-sbtc: monthly-rent-sbtc, 
          min-investment-sbtc: min-investment-sbtc,
          is-verified: false, 
          is-active: false, 
          created-at: stacks-block-height, 
          funding-deadline: funding-deadline, 
          funding-threshold: funding-threshold, 
          funding-status: "pending", 
          is-liquidated: false, 
          liquidation-value: u0,
          funds-released: false, 
          funds-release-date: u0,
          deadline-checked: false,
          verification-score: u0,
          verified-by-governance: false
        })
      
      (var-set property-counter property-id)
      
      (print { 
        e: "submit",
        p: property-id, 
        o: tx-sender, 
        v: total-value-sbtc 
      })
      (ok property-id))))

(define-public (verify-property (property-id uint))
  (let ((property (unwrap! (get-property property-id) ERR_PROPERTY_NOT_FOUND)))
    (asserts! (is-admin-or-owner tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (not (get is-verified property)) ERR_PROPERTY_ALREADY_EXISTS)
    
    (map-set properties 
      { property-id: property-id }
      (merge property { 
        is-verified: true, 
        is-active: true, 
        funding-status: "active" 
      }))
    
    (print { e: "verify", p: property-id })
    (ok true)))

(define-public (update-property-investment (property-id uint) (additional-investment uint))
  (let ((property (unwrap! (get-property property-id) ERR_PROPERTY_NOT_FOUND)))
    (asserts! (or (is-eq contract-caller .investment-manager-v3)
                  (is-eq contract-caller .rental-distributor-v3))
              ERR_UNAUTHORIZED_CALLER)
    (asserts! (and (> property-id u0) (> additional-investment u0)) ERR_INVALID_INPUT)
    
    (let ((new-total (unwrap! (safe-add (get total-invested-sbtc property) additional-investment) ERR_ARITHMETIC_OVERFLOW)))
      (asserts! (<= new-total (get total-value-sbtc property)) ERR_INVALID_AMOUNT)
      (map-set properties 
        { property-id: property-id } 
        (merge property { total-invested-sbtc: new-total })))
    
    (print { 
      e: "invest-update",
      p: property-id, 
      a: additional-investment 
    })
    (ok true)))

(define-public (check-funding-deadline (property-id uint))
  (let ((property (unwrap! (get-property property-id) ERR_PROPERTY_NOT_FOUND)))
    (asserts! (>= stacks-block-height (get funding-deadline property)) ERR_INVALID_INPUT)
    (asserts! (is-eq (get funding-status property) "active") ERR_PROPERTY_ALREADY_EXISTS)
    
    (let (
      (funding-pct (unwrap! (safe-div (unwrap! (safe-mul (get total-invested-sbtc property) BASIS_POINTS_SCALE) ERR_ARITHMETIC_OVERFLOW)
                                       (get total-value-sbtc property))
                             ERR_ARITHMETIC_OVERFLOW))
    )
      (if (>= funding-pct (get funding-threshold property))
        (begin 
          (map-set properties 
            { property-id: property-id } 
            (merge property { 
              funding-status: "funded",
              deadline-checked: true
            }))
          (print { e: "funded", p: property-id })
          (ok "funded"))
        (begin 
          (map-set properties 
            { property-id: property-id } 
            (merge property { 
              funding-status: "failed", 
              is-active: false,
              deadline-checked: true
            }))
          (print { e: "failed", p: property-id })
          (ok "failed"))))))

;; Release-funds-to-owner: state update before transfer, proper as-contract usage
(define-public (release-funds-to-owner (property-id uint))
  (let ((property (unwrap! (get-property property-id) ERR_PROPERTY_NOT_FOUND)))
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (unwrap! (check-emergency-status) ERR_CONTRACT_PAUSED)
    (asserts! (or (is-admin-or-owner tx-sender) 
                  (is-eq tx-sender (get owner property))) ERR_NOT_AUTHORIZED)
    
    (asserts! (and (is-eq (get funding-status property) "funded")
                   (not (get funds-released property))
                   (> stacks-block-height (+ (get funding-deadline property) FUNDS_RELEASE_DELAY)))
              ERR_FUNDING_INCOMPLETE)
    
    ;; Just mark funds as ready for release, don't transfer
    (map-set properties 
      { property-id: property-id }
      (merge property { 
        funds-released: true, 
        funds-release-date: stacks-block-height 
      }))
    
    (print { 
      e: "release-approved",
      p: property-id, 
      a: (get total-invested-sbtc property), 
      to: (get owner property) 
    })
    (ok (get total-invested-sbtc property))))

(define-public (update-property-rent (property-id uint) (new-monthly-rent uint))
  (let ((property (unwrap! (get-property property-id) ERR_PROPERTY_NOT_FOUND)))
    (asserts! (or (is-eq tx-sender (get owner property)) 
                  (is-admin-or-owner tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (and (> new-monthly-rent u0)
                   (is-realistic-rent-yield new-monthly-rent (get total-value-sbtc property)))
              ERR_RENT_YIELD_UNREALISTIC)
    
    (map-set properties 
      { property-id: property-id } 
      (merge property { monthly-rent-sbtc: new-monthly-rent }))
    
    (print { 
      e: "rent-update",
      p: property-id, 
      r: new-monthly-rent 
    })
    (ok true)))

;; GOVERNANCE FUNCTIONS
(define-public (create-governance-proposal
    (property-id uint) 
    (proposal-type (string-ascii 50)) 
    (description (string-ascii 300)) 
    (new-value uint) 
    (new-principal-opt (optional principal)))
  (let (
    (proposal-id (+ (var-get proposal-counter) u1))
    (voting-deadline (+ stacks-block-height VOTING_PERIOD))
    (property (unwrap! (get-property property-id) ERR_PROPERTY_NOT_FOUND))
    (snapshot-investment (get total-invested-sbtc property))
  )
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    
    (asserts! (and (> property-id u0)
                   (> (len proposal-type) u0)
                   (<= (len proposal-type) u50)
                   (> (len description) u10)
                   (<= (len description) u300)
                   (<= new-value u1000000000))
              ERR_INVALID_INPUT)
    
    (asserts! (or (is-eq proposal-type "update-rent")
                  (is-eq proposal-type "change-owner")
                  (is-eq proposal-type "liquidate")
                  (is-eq proposal-type "update-threshold")
                  (is-eq proposal-type "extend-deadline"))
              ERR_INVALID_INPUT)
    
    (if (is-eq proposal-type "liquidate")
      (let ((min-liquidation (unwrap! (safe-div (unwrap! (safe-mul (get total-value-sbtc property) MIN_LIQUIDATION_PCT) 
                                                          ERR_ARITHMETIC_OVERFLOW) 
                                                 BASIS_POINTS_SCALE) 
                                      ERR_ARITHMETIC_OVERFLOW)))
        (asserts! (>= new-value min-liquidation) ERR_LIQUIDATION_TOO_LOW))
      true)
    
    (let (
      (validated-principal 
        (match new-principal-opt
          principal-val (if (is-standard principal-val)
                         (some principal-val)
                         none)
          none))
    )
      (asserts! (or (is-none new-principal-opt)
                    (is-some validated-principal))
                ERR_INVALID_INPUT)
      
      (map-set governance-proposals 
        { proposal-id: proposal-id }
        { 
          property-id: property-id, 
          proposal-type: proposal-type, 
          description: description, 
          proposed-by: tx-sender, 
          created-at: stacks-block-height, 
          voting-deadline: voting-deadline,
          votes-for: u0, 
          votes-against: u0, 
          total-voting-power: u0, 
          executed: false, 
          execution-block: u0, 
          new-value: new-value,
          new-principal: validated-principal,
          snapshot-total-investment: snapshot-investment
        }))
    
    (var-set proposal-counter proposal-id)
    
    (print { 
      e: "proposal",
      id: proposal-id, 
      p: property-id, 
      t: proposal-type,
      s: snapshot-investment
    })
    (ok proposal-id)))

;; Signature to match investment-manager-v3: takes 4 parameters (proposal-id, voter, vote-for, voting-power)
(define-public (record-vote 
    (proposal-id uint) 
    (voter principal) 
    (vote-for bool)
    (voting-power uint))
  (let (
    (proposal (unwrap! (get-proposal proposal-id) ERR_PROPERTY_NOT_FOUND))
  )
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    
    ;; Allow direct calls when tx-sender equals voter, OR when called from authorized contracts
    (asserts! (or (is-eq tx-sender voter)
                  (is-eq contract-caller .investment-manager-v3)
                  (is-eq contract-caller .rental-distributor-v3))
              ERR_NOT_AUTHORIZED)
    
    (asserts! (and (is-none (get-user-vote proposal-id voter))
                   (<= stacks-block-height (get voting-deadline proposal))
                   (> voting-power u0)
                   (<= voting-power BASIS_POINTS_SCALE))
              ERR_ALREADY_VOTED)
    
    (map-set proposal-votes 
      { proposal-id: proposal-id, voter: voter } 
      { vote-weight: voting-power, vote-for: vote-for })
    
    (map-set governance-proposals 
      { proposal-id: proposal-id }
      (merge proposal {
        votes-for: (if vote-for 
                     (+ (get votes-for proposal) voting-power) 
                     (get votes-for proposal)),
        votes-against: (if vote-for 
                         (get votes-against proposal) 
                         (+ (get votes-against proposal) voting-power)),
        total-voting-power: (+ (get total-voting-power proposal) voting-power) 
      }))
    
    (print { 
      e: "vote",
      id: proposal-id, 
      v: voter, 
      f: vote-for, 
      w: voting-power 
    })
    (ok true)))

(define-public (execute-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (get-proposal proposal-id) ERR_PROPERTY_NOT_FOUND))
    (property (unwrap! (get-property (get property-id proposal)) ERR_PROPERTY_NOT_FOUND))
  )
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    
    (asserts! (and (not (get executed proposal))
                   (> stacks-block-height (+ (get voting-deadline proposal) PROPOSAL_EXECUTION_DELAY))
                   (< stacks-block-height (+ (get voting-deadline proposal) PROPOSAL_EXPIRY_PERIOD))
                   (> (get votes-for proposal) (get votes-against proposal)))
              ERR_PROPOSAL_NOT_PASSED)
    
    ;; Allow execution if snapshot is 0 OR if quorum requirements are met
    (let (
      (snapshot-investment (get snapshot-total-investment proposal))
      (required-quorum (unwrap! (safe-div (unwrap! (safe-mul snapshot-investment QUORUM_PERCENTAGE) ERR_ARITHMETIC_OVERFLOW) 
                                          BASIS_POINTS_SCALE) 
                                ERR_ARITHMETIC_OVERFLOW))
      (required-participation (unwrap! (safe-div (unwrap! (safe-mul snapshot-investment MIN_PARTICIPATION_PCT) ERR_ARITHMETIC_OVERFLOW) 
                                                 BASIS_POINTS_SCALE) 
                                       ERR_ARITHMETIC_OVERFLOW))
    )
      (if (> snapshot-investment u0)
        (asserts! (and (>= (get total-voting-power proposal) required-quorum)
                       (>= (get total-voting-power proposal) required-participation))
                  ERR_INSUFFICIENT_VOTES)
        true))
    
    (let (
      (execution-result
        (if (is-eq (get proposal-type proposal) "update-rent")
          (begin
            (asserts! (and (> (get new-value proposal) u0)
                           (is-realistic-rent-yield (get new-value proposal) (get total-value-sbtc property)))
                      ERR_RENT_YIELD_UNREALISTIC)
            (map-set properties 
              { property-id: (get property-id proposal) }
              (merge property { monthly-rent-sbtc: (get new-value proposal) }))
            (ok true))
          
          (if (is-eq (get proposal-type proposal) "change-owner")
            (begin
              (let ((new-owner (unwrap! (get new-principal proposal) ERR_INVALID_INPUT)))
                (asserts! (is-standard new-owner) ERR_INVALID_INPUT)
                (map-set properties 
                  { property-id: (get property-id proposal) }
                  (merge property { owner: new-owner }))
                (ok true)))
            
            (if (is-eq (get proposal-type proposal) "liquidate")
              (begin
                (asserts! (> (get new-value proposal) u0) ERR_INVALID_AMOUNT)
                (map-set properties 
                  { property-id: (get property-id proposal) }
                  (merge property { 
                    is-liquidated: true, 
                    is-active: false, 
                    liquidation-value: (get new-value proposal) 
                  }))
                (ok true))
              
              (if (is-eq (get proposal-type proposal) "update-threshold")
                (begin
                  (asserts! (and 
                              (>= (get new-value proposal) MIN_FUNDING_THRESHOLD)
                              (<= (get new-value proposal) MAX_FUNDING_THRESHOLD))
                            ERR_INVALID_INPUT)
                  (map-set properties 
                    { property-id: (get property-id proposal) }
                    (merge property { funding-threshold: (get new-value proposal) }))
                  (ok true))
                
                (if (is-eq (get proposal-type proposal) "extend-deadline")
                  (begin
                    (asserts! (and (> (get new-value proposal) u0) (<= (get new-value proposal) u90))
                              ERR_INVALID_INPUT)
                    (let ((new-deadline (+ (get funding-deadline property) 
                                          (unwrap! (safe-mul (get new-value proposal) BLOCKS_PER_DAY) 
                                                   ERR_ARITHMETIC_OVERFLOW))))
                      (map-set properties 
                        { property-id: (get property-id proposal) }
                        (merge property { funding-deadline: new-deadline }))
                      (ok true)))
                  (ok true))))))))
      
      (unwrap! execution-result ERR_INVALID_INPUT)
      
      (map-set governance-proposals 
        { proposal-id: proposal-id }
        (merge proposal { 
          executed: true, 
          execution-block: stacks-block-height 
        }))
      
      (print { 
        e: "executed",
        id: proposal-id, 
        t: (get proposal-type proposal) 
      })
      
      (ok true))))

;; LIQUIDATION FUNCTIONS
(define-public (claim-liquidation-proceeds (property-id uint))
  (let (
    (property (unwrap! (get-property property-id) ERR_PROPERTY_NOT_FOUND))
    (user-investment (contract-call? .data-store-v3 get-user-investment property-id tx-sender))
    (user-invested (get sbtc-invested user-investment))
    (property-totals (contract-call? .data-store-v3 get-property-investment-totals property-id))
    (total-investment (get total-sbtc-invested property-totals))
    (existing-claim (map-get? liquidation-claims { property-id: property-id, investor: tx-sender }))
  )
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    
    (asserts! (and (get is-liquidated property)
                   (> user-invested u0)
                   (is-none existing-claim))
              ERR_PROPERTY_NOT_LIQUIDATED)
    
    (let ((user-share (unwrap! (safe-div (unwrap! (safe-mul (get liquidation-value property) user-invested) 
                                                   ERR_ARITHMETIC_OVERFLOW) 
                                         total-investment) 
                               ERR_ARITHMETIC_OVERFLOW)))
      (asserts! (> user-share u0) ERR_INVALID_AMOUNT)
      
      (map-set liquidation-claims
        { property-id: property-id, investor: tx-sender }
        {
          claimed: true,
          amount-claimed: user-share,
          claim-date: stacks-block-height
        })
      
      (match (as-contract (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token transfer 
                user-share 
                (as-contract tx-sender)
                tx-sender 
                (some 0x4c69717569646174696f6e)))
        success-val
          (begin
            (print { 
              e: "liq-claim",
              p: property-id, 
              i: tx-sender, 
              a: user-share 
            })
            (ok user-share))
        error-val ERR_INVALID_AMOUNT))))

;; SECONDARY MARKET FUNCTIONS
(define-public (list-shares-for-sale 
    (property-id uint) 
    (shares-for-sale uint) 
    (price-per-share uint))
  (begin
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (unwrap! (check-emergency-status) ERR_CONTRACT_PAUSED)
    (unwrap! (get-property property-id) ERR_PROPERTY_NOT_FOUND)
    (asserts! (and (> property-id u0)
                   (> shares-for-sale u0)
                   (> price-per-share u0)
                   (<= shares-for-sale u1000000000))
              ERR_INVALID_AMOUNT)
    
    (let ((user-investment (contract-call? .data-store-v3 get-user-investment property-id tx-sender)))
      (asserts! (>= (get sbtc-invested user-investment) shares-for-sale) ERR_INSUFFICIENT_SHARES))
    
    (let ((existing-listing (get-share-listing property-id tx-sender)))
      (match existing-listing
        listing (asserts! (not (get is-active listing)) ERR_SHARES_NOT_AVAILABLE)
        true))
    
    (map-set share-listings 
      { property-id: property-id, seller: tx-sender }
      { 
        shares-for-sale: shares-for-sale, 
        price-per-share: price-per-share, 
        is-active: true, 
        shares-locked: shares-for-sale, 
        listing-date: stacks-block-height,
        version: u1
      })
    
    (print { 
      e: "list",
      p: property-id, 
      s: tx-sender, 
      sh: shares-for-sale, 
      pr: price-per-share 
    })
    (ok true)))

(define-public (cancel-share-listing (property-id uint))
  (let ((listing (unwrap! (get-share-listing property-id tx-sender) ERR_LISTING_NOT_FOUND)))
    (asserts! (and (not (var-get contract-paused))
                   (get is-active listing))
              ERR_LISTING_NOT_FOUND)
    
    (map-set share-listings 
      { property-id: property-id, seller: tx-sender }
      (merge listing { 
        is-active: false, 
        shares-locked: u0 
      }))
    
    (print { e: "cancel", p: property-id, s: tx-sender })
    (ok true)))

(define-public (update-share-listing-price 
    (property-id uint) 
    (new-price-per-share uint))
  (let ((listing (unwrap! (get-share-listing property-id tx-sender) ERR_LISTING_NOT_FOUND)))
    (asserts! (and (not (var-get contract-paused))
                   (get is-active listing)
                   (> new-price-per-share u0))
              ERR_LISTING_NOT_FOUND)
    
    (map-set share-listings 
      { property-id: property-id, seller: tx-sender }
      (merge listing { 
        price-per-share: new-price-per-share,
        version: (+ (get version listing) u1)
      }))
    
    (print { 
      e: "price-update",
      p: property-id, 
      s: tx-sender, 
      pr: new-price-per-share 
    })
    (ok true)))

(define-public (update-listing-after-purchase 
    (property-id uint) 
    (seller principal) 
    (shares-purchased uint))
  (let ((listing (unwrap! (get-share-listing property-id seller) ERR_LISTING_NOT_FOUND)))
    (asserts! (or (is-eq contract-caller .investment-manager-v3)
                  (is-eq contract-caller .rental-distributor-v3))
              ERR_UNAUTHORIZED_CALLER)
    (asserts! (and (is-standard seller)
                   (> property-id u0)
                   (> shares-purchased u0)
                   (get is-active listing)
                   (>= (get shares-locked listing) shares-purchased))
              ERR_SHARES_NOT_AVAILABLE)
    
    (let (
      (remaining-shares (unwrap! (safe-sub (get shares-for-sale listing) shares-purchased) ERR_ARITHMETIC_OVERFLOW))
      (remaining-locked (unwrap! (safe-sub (get shares-locked listing) shares-purchased) ERR_ARITHMETIC_OVERFLOW))
    )
      (if (is-eq remaining-shares u0)
        (map-set share-listings 
          { property-id: property-id, seller: seller }
          (merge listing { 
            shares-for-sale: u0, 
            is-active: false, 
            shares-locked: u0 
          }))
        (map-set share-listings 
          { property-id: property-id, seller: seller }
          (merge listing { 
            shares-for-sale: remaining-shares, 
            shares-locked: remaining-locked 
          }))))
    
    (print { 
      e: "list-update",
      p: property-id, 
      s: seller, 
      sh: shares-purchased 
    })
    (ok true)))

;; Admin-cancel-listing: make listing optional, create if doesn't exist
(define-public (admin-cancel-listing 
    (property-id uint) 
    (seller principal))
  (let (
    (property (unwrap! (get-property property-id) ERR_PROPERTY_NOT_FOUND))
  )
    (asserts! (is-admin-or-owner tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (and (is-standard seller)
                   (> property-id u0))
              ERR_PROPERTY_NOT_FOUND)
    
    ;; Get listing or create default cancelled listing
    (let ((listing (default-to 
                     { shares-for-sale: u0, price-per-share: u0, is-active: false, 
                       shares-locked: u0, listing-date: u0, version: u0 }
                     (get-share-listing property-id seller))))
      
      (map-set share-listings 
        { property-id: property-id, seller: seller }
        (merge listing { 
          is-active: false, 
          shares-locked: u0 
        }))
      
      (print { 
        e: "admin-cancel",
        p: property-id, 
        s: seller 
      })
      (ok true))))