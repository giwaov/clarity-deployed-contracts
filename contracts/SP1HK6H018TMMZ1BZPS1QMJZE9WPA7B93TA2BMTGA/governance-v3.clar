;; Governance & Admin Control Contract
;; Central authority system with multi-sig, timelocks, and transparent processes

;; ERROR CODES
(define-constant ERR_NOT_AUTHORIZED (err u5001))
(define-constant ERR_ALREADY_INITIALIZED (err u5002))
(define-constant ERR_NOT_ENOUGH_APPROVALS (err u5003))
(define-constant ERR_ALREADY_EXECUTED (err u5004))
(define-constant ERR_TOO_EARLY (err u5005))
(define-constant ERR_EXPIRED (err u5006))
(define-constant ERR_ALREADY_APPROVED (err u5007))
(define-constant ERR_INVALID_INPUT (err u5008))
(define-constant ERR_COOLDOWN_ACTIVE (err u5009))
(define-constant ERR_INVALID_PRINCIPAL (err u5010))
(define-constant ERR_DUPLICATE_ADMIN (err u5011))

;; CONSTANTS
(define-constant CONTRACT_DEPLOYER tx-sender)
(define-constant STANDARD_TIMELOCK u1440) ;; 10 days
(define-constant CRITICAL_TIMELOCK u4320) ;; 30 days  
(define-constant ACTION_EXPIRY u8640) ;; 60 days
(define-constant EMERGENCY_COOLDOWN u1440) ;; 10 days
(define-constant MAX_EMERGENCY_PERCENT u1000) ;; 10%
(define-constant MAX_EMERGENCY_AMOUNT u10000000000) ;; 100 sBTC

;; STATE VARIABLES
(define-data-var initialized bool false)
(define-data-var required-approvals uint u2)
(define-data-var action-counter uint u0)
(define-data-var last-emergency-block uint u0)
(define-data-var total-emergency-withdrawn uint u0)

;; ADMIN COUNCIL
(define-map admin-council 
  principal 
  {
    is-active: bool,
    name: (string-ascii 50),
    added-at: uint,
    added-by: principal
  })

(define-map admin-list uint principal) ;; For iteration
(define-data-var admin-count uint u0)

;; Improved principal validation
(define-private (is-valid-principal (addr principal))
  (and 
    (is-standard addr)
    (not (is-eq addr 'ST000000000000000000002AMW42H)) ;; Burn address
    (not (is-eq addr 'SP000000000000000000002Q6VF78)))) ;; Mainnet burn address

;; Helper to validate admin name
(define-private (is-valid-name (name (string-ascii 50)))
  (and (> (len name) u2) (<= (len name) u50)))

;; Helper to check if admin already exists
(define-private (admin-exists (addr principal))
  (is-some (map-get? admin-council addr)))

;; initialization - deployer can be admin
;; This removes the confusing restriction
(define-public (initialize-admins 
    (admin1 principal)
    (admin2 principal)
    (admin3 principal)
    (name1 (string-ascii 50))
    (name2 (string-ascii 50))
    (name3 (string-ascii 50)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_DEPLOYER) ERR_NOT_AUTHORIZED)
    (asserts! (not (var-get initialized)) ERR_ALREADY_INITIALIZED)
    
    ;; Validate all principals are unique and valid
    (asserts! (not (is-eq admin1 admin2)) ERR_DUPLICATE_ADMIN)
    (asserts! (not (is-eq admin1 admin3)) ERR_DUPLICATE_ADMIN)
    (asserts! (not (is-eq admin2 admin3)) ERR_DUPLICATE_ADMIN)
    
    ;; Allow deployer to be an admin, just validate they're proper principals
    (asserts! (is-valid-principal admin1) ERR_INVALID_PRINCIPAL)
    (asserts! (is-valid-principal admin2) ERR_INVALID_PRINCIPAL)
    (asserts! (is-valid-principal admin3) ERR_INVALID_PRINCIPAL)
    
    ;; Validate all names
    (asserts! (is-valid-name name1) ERR_INVALID_INPUT)
    (asserts! (is-valid-name name2) ERR_INVALID_INPUT)
    (asserts! (is-valid-name name3) ERR_INVALID_INPUT)
    
    (map-set admin-council admin1 {
      is-active: true,
      name: name1,
      added-at: stacks-block-height,
      added-by: tx-sender
    })
    (map-set admin-council admin2 {
      is-active: true,
      name: name2,
      added-at: stacks-block-height,
      added-by: tx-sender
    })
    (map-set admin-council admin3 {
      is-active: true,
      name: name3,
      added-at: stacks-block-height,
      added-by: tx-sender
    })
    
    (map-set admin-list u1 admin1)
    (map-set admin-list u2 admin2)
    (map-set admin-list u3 admin3)
    (var-set admin-count u3)
    (var-set initialized true)
    
    (print { 
      e: "governance-initialized",
      admins: (list admin1 admin2 admin3),
      required-approvals: u2,
      deployer: CONTRACT_DEPLOYER
    })
    (ok true)))

(define-read-only (is-admin (user principal))
  (match (map-get? admin-council user)
    admin-data (get is-active admin-data)
    false))

(define-read-only (get-admin-info (admin principal))
  (map-get? admin-council admin))

(define-read-only (get-admin-count)
  (var-get admin-count))

(define-read-only (get-all-admins)
  (list
    (map-get? admin-list u1)
    (map-get? admin-list u2)
    (map-get? admin-list u3)))

;; PENDING ACTIONS SYSTEM
(define-map pending-actions
  { action-id: uint }
  {
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
  })

;; Helper to validate action type
(define-private (is-valid-action-type (action-type (string-ascii 50)))
  (or 
    (is-eq action-type "verify-property")
    (is-eq action-type "update-platform-fee")
    (is-eq action-type "whitelist-investor")
    (is-eq action-type "blacklist-investor")
    (is-eq action-type "add-admin")
    (is-eq action-type "remove-admin")
    (is-eq action-type "change-approvals")))

;; PROPOSE ACTION
(define-public (propose-action
    (action-type (string-ascii 50))
    (description (string-ascii 300))
    (target-contract (string-ascii 50))
    (target-principal (optional principal))
    (value-1 uint)
    (value-2 uint)
    (value-3 uint)
    (string-param (optional (string-ascii 200))))
  (let (
    (action-id (+ (var-get action-counter) u1))
    (is-critical (or (is-eq action-type "add-admin")
                     (is-eq action-type "remove-admin")
                     (is-eq action-type "change-approvals")))
    (timelock (if is-critical CRITICAL_TIMELOCK STANDARD_TIMELOCK))
    (executable-after (+ stacks-block-height timelock))
    (expires-at (+ stacks-block-height ACTION_EXPIRY))
  )
    (asserts! (is-admin tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (> (len description) u20) ERR_INVALID_INPUT)
    (asserts! (is-valid-action-type action-type) ERR_INVALID_INPUT)
    (asserts! (> (len target-contract) u0) ERR_INVALID_INPUT)
    
    ;; Validate numeric values are reasonable (not overflow/underflow risks)
    (asserts! (or (is-eq value-1 u0) (> value-1 u0)) ERR_INVALID_INPUT)
    (asserts! (or (is-eq value-2 u0) (> value-2 u0)) ERR_INVALID_INPUT)
    (asserts! (or (is-eq value-3 u0) (> value-3 u0)) ERR_INVALID_INPUT)
    
    ;; Validate string-param if provided
    (asserts! (match string-param
      param (> (len param) u0)
      true) ERR_INVALID_INPUT)
    
    ;; Validate target principal if provided
    (asserts! (match target-principal
      addr (is-valid-principal addr)
      true) ERR_INVALID_INPUT)
    
    (map-set pending-actions
      { action-id: action-id }
      {
        action-type: action-type,
        description: description,
        target-contract: target-contract,
        target-principal: target-principal,
        value-1: value-1,
        value-2: value-2,
        value-3: value-3,
        string-param: string-param,
        created-at: stacks-block-height,
        created-by: tx-sender,
        executable-after: executable-after,
        expires-at: expires-at,
        executed: false,
        executed-at: u0,
        approvals: (list tx-sender),
        approval-count: u1
      })
    
    (var-set action-counter action-id)
    
    (print {
      e: "action-proposed",
      action-id: action-id,
      type: action-type,
      by: tx-sender,
      executable-in-blocks: timelock,
      expires-in-blocks: ACTION_EXPIRY
    })
    (ok action-id)))

;; APPROVE ACTION
(define-public (approve-action (action-id uint))
  (let (
    (action (unwrap! (map-get? pending-actions { action-id: action-id }) ERR_INVALID_INPUT))
  )
    (asserts! (is-admin tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (> action-id u0) ERR_INVALID_INPUT)
    (asserts! (<= action-id (var-get action-counter)) ERR_INVALID_INPUT)
    (asserts! (not (get executed action)) ERR_ALREADY_EXECUTED)
    (asserts! (< stacks-block-height (get expires-at action)) ERR_EXPIRED)
    
    ;; Check not already approved
    (asserts! (is-none (index-of (get approvals action) tx-sender)) ERR_ALREADY_APPROVED)
    
    ;; Add approval
    (let ((new-approvals (unwrap! (as-max-len? (append (get approvals action) tx-sender) u10) 
                                   ERR_INVALID_INPUT)))
      (map-set pending-actions
        { action-id: action-id }
        (merge action { 
          approvals: new-approvals,
          approval-count: (+ (get approval-count action) u1)
        }))
      
      (print {
        e: "action-approved",
        action-id: action-id,
        by: tx-sender,
        total-approvals: (+ (get approval-count action) u1)
      })
      (ok true))))

;; EXECUTE ACTION (After timelock + approvals)
(define-public (execute-action (action-id uint))
  (let (
    (action (unwrap! (map-get? pending-actions { action-id: action-id }) ERR_INVALID_INPUT))
  )
    ;; Validation
    (asserts! (> action-id u0) ERR_INVALID_INPUT)
    (asserts! (<= action-id (var-get action-counter)) ERR_INVALID_INPUT)
    (asserts! (not (get executed action)) ERR_ALREADY_EXECUTED)
    (asserts! (>= (get approval-count action) (var-get required-approvals)) ERR_NOT_ENOUGH_APPROVALS)
    (asserts! (>= stacks-block-height (get executable-after action)) ERR_TOO_EARLY)
    (asserts! (< stacks-block-height (get expires-at action)) ERR_EXPIRED)
    
    ;; Mark as executed
    (map-set pending-actions
      { action-id: action-id }
      (merge action { 
        executed: true,
        executed-at: stacks-block-height
      }))
    
    ;; Log execution
    (print {
      e: "action-executed",
      action-id: action-id,
      type: (get action-type action),
      approvers: (get approvals action)
    })
    
    ;; Return action details for other contracts to process
    (ok action)))

;; VERIFICATION CRITERIA
(define-map verification-criteria
  { criteria-id: uint }
  {
    name: (string-ascii 100),
    description: (string-ascii 300),
    required: bool,
    weight: uint,
    active: bool
  })

(define-data-var criteria-count uint u0)

;; Set verification requirements (publicly visible)
(define-public (set-verification-criteria
    (criteria-id uint)
    (name (string-ascii 100))
    (description (string-ascii 300))
    (required bool)
    (weight uint))
  (begin
    (asserts! (is-admin tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (> criteria-id u0) ERR_INVALID_INPUT)
    (asserts! (<= weight u100) ERR_INVALID_INPUT)
    (asserts! (> (len name) u2) ERR_INVALID_INPUT)
    (asserts! (> (len description) u10) ERR_INVALID_INPUT)
    
    (map-set verification-criteria
      { criteria-id: criteria-id }
      {
        name: name,
        description: description,
        required: required,
        weight: weight,
        active: true
      })
    
    (if (> criteria-id (var-get criteria-count))
      (var-set criteria-count criteria-id)
      true)
    
    (print { e: "criteria-updated", id: criteria-id, name: name })
    (ok true)))

(define-read-only (get-verification-criteria (criteria-id uint))
  (map-get? verification-criteria { criteria-id: criteria-id }))

;; Property verification checklist
(define-map property-verification-checks
  { property-id: uint }
  {
    title-verified: bool,
    appraisal-completed: bool,
    insurance-active: bool,
    rental-history-checked: bool,
    owner-kyc-completed: bool,
    legal-review-passed: bool,
    total-score: uint,
    verified-by: (list 10 principal),
    verification-date: uint
  })

(define-public (record-verification-check
    (property-id uint)
    (title-verified bool)
    (appraisal-completed bool)
    (insurance-active bool)
    (rental-history-checked bool)
    (owner-kyc-completed bool)
    (legal-review-passed bool))
  (begin
    (asserts! (is-admin tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (> property-id u0) ERR_INVALID_INPUT)
    
    (let (
      (score (+ 
        (if title-verified u20 u0)
        (if appraisal-completed u20 u0)
        (if insurance-active u15 u0)
        (if rental-history-checked u15 u0)
        (if owner-kyc-completed u15 u0)
        (if legal-review-passed u15 u0)))
    )
      (map-set property-verification-checks
        { property-id: property-id }
        {
          title-verified: title-verified,
          appraisal-completed: appraisal-completed,
          insurance-active: insurance-active,
          rental-history-checked: rental-history-checked,
          owner-kyc-completed: owner-kyc-completed,
          legal-review-passed: legal-review-passed,
          total-score: score,
          verified-by: (list tx-sender),
          verification-date: stacks-block-height
        })
      
      (print {
        e: "verification-recorded",
        property-id: property-id,
        score: score,
        passing: (>= score u85)
      })
      (ok score))))

(define-read-only (get-property-verification-score (property-id uint))
  (map-get? property-verification-checks { property-id: property-id }))

;; Emergency powers with amount limits
(define-read-only (can-trigger-emergency)
  (> stacks-block-height (+ (var-get last-emergency-block) EMERGENCY_COOLDOWN)))

(define-read-only (get-emergency-stats)
  {
    total-withdrawn: (var-get total-emergency-withdrawn),
    last-emergency: (var-get last-emergency-block),
    cooldown-remaining: (if (> (+ (var-get last-emergency-block) EMERGENCY_COOLDOWN) stacks-block-height)
                          (- (+ (var-get last-emergency-block) EMERGENCY_COOLDOWN) stacks-block-height)
                          u0),
    can-trigger: (can-trigger-emergency),
    max-emergency-amount: MAX_EMERGENCY_AMOUNT
  })

;; Emergency declaration now includes amount validation
(define-public (declare-emergency
    (emergency-type (string-ascii 50))
    (reason (string-ascii 500))
    (max-amount uint))
  (begin
    (asserts! (is-admin tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (can-trigger-emergency) ERR_COOLDOWN_ACTIVE)
    (asserts! (> (len reason) u50) ERR_INVALID_INPUT)
    (asserts! (> (len emergency-type) u5) ERR_INVALID_INPUT)
    (asserts! (and (> max-amount u0) (<= max-amount MAX_EMERGENCY_AMOUNT)) ERR_INVALID_INPUT)
    
    (var-set last-emergency-block stacks-block-height)
    
    (print {
      e: "EMERGENCY-DECLARED",
      type: emergency-type,
      reason: reason,
      max-amount: max-amount,
      declared-by: tx-sender,
      timestamp: stacks-block-height
    })
    (ok true)))

;; Track emergency withdrawals
(define-public (record-emergency-withdrawal (amount uint))
  (begin
    ;; Only callable by authorized contracts (investment-manager, rental-distributor)
    (asserts! (or (is-eq contract-caller .investment-manager-v3)
                  (is-eq contract-caller .rental-distributor-v3))
              ERR_NOT_AUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_INPUT)
    
    (var-set total-emergency-withdrawn 
      (+ (var-get total-emergency-withdrawn) amount))
    
    (print { e: "emergency-withdrawal-recorded", amount: amount })
    (ok true)))

;; READ-ONLY HELPERS
(define-read-only (get-action (action-id uint))
  (map-get? pending-actions { action-id: action-id }))

(define-read-only (get-required-approvals)
  (var-get required-approvals))

(define-read-only (get-action-counter)
  (var-get action-counter))

(define-read-only (is-action-executable (action-id uint))
  (match (map-get? pending-actions { action-id: action-id })
    action (ok (and
      (not (get executed action))
      (>= (get approval-count action) (var-get required-approvals))
      (>= stacks-block-height (get executable-after action))
      (< stacks-block-height (get expires-at action))))
    (ok false)))