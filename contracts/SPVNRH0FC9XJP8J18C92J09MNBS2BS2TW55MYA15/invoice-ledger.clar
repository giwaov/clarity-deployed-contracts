;; title: invoice-ledger
;; version:
;; summary:
;; description:

;; Impact Sustainability Tracking Smart Contract
;; A comprehensive system for tracking environmental and social impact metrics

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_INPUT (err u102))
(define-constant ERR_ALREADY_EXISTS (err u103))
(define-constant ERR_INVALID_PERIOD (err u104))
(define-constant ERR_INSUFFICIENT_BALANCE (err u105))
(define-constant ERR_INVALID_VERIFICATION (err u106))
(define-constant ERR_EXPIRED (err u107))

;; Impact category constants
(define-constant CARBON_REDUCTION u1)
(define-constant RENEWABLE_ENERGY u2)
(define-constant WASTE_REDUCTION u3)
(define-constant WATER_CONSERVATION u4)
(define-constant BIODIVERSITY u5)
(define-constant SOCIAL_IMPACT u6)

;; Input validation constants
(define-constant MAX_FEE u1000000000) ;; 1000 STX max fee
(define-constant MAX_STAKE u100000000000) ;; 100,000 STX max stake
(define-constant MAX_PROJECT_ID u1000000) ;; Max project ID
(define-constant MAX_RECORD_ID u1000000) ;; Max record ID
(define-constant MAX_MILESTONE_ID u1000) ;; Max milestone ID
(define-constant MAX_REWARD u10000000000) ;; 10,000 STX max reward

;; Data Variables
(define-data-var contract-active bool true)
(define-data-var total-projects uint u0)
(define-data-var verification-fee uint u1000000) ;; 1 STX in microSTX
(define-data-var min-stake-amount uint u5000000) ;; 5 STX minimum stake

;; Data Maps

;; Project registry
(define-map projects
  { project-id: uint }
  {
    owner: principal,
    name: (string-ascii 100),
    description: (string-utf8 500),
    category: uint,
    target-impact: uint,
    current-impact: uint,
    created-at: uint,
    expires-at: uint,
    verified: bool,
    stake-amount: uint,
    active: bool
  }
)

;; Impact records for detailed tracking
(define-map impact-records
  { project-id: uint, record-id: uint }
  {
    reporter: principal,
    impact-value: uint,
    evidence-hash: (string-ascii 64),
    timestamp: uint,
    verified: bool,
    verifier: (optional principal)
  }
)

;; Project impact record counters
(define-map project-record-counts
  { project-id: uint }
  { count: uint }
)

;; Verifier registry
(define-map verifiers
  { verifier: principal }
  {
    reputation: uint,
    total-verifications: uint,
    successful-verifications: uint,
    registered-at: uint,
    active: bool
  }
)

;; Stakeholder balances
(define-map stakeholder-balances
  { stakeholder: principal }
  { balance: uint }
)

;; Project stakeholder tracking
(define-map project-stakeholders
  { project-id: uint, stakeholder: principal }
  { stake-amount: uint, joined-at: uint }
)

;; Impact achievements and milestones
(define-map project-milestones
  { project-id: uint, milestone-id: uint }
  {
    description: (string-utf8 200),
    target-value: uint,
    achieved: bool,
    achieved-at: (optional uint),
    reward-amount: uint
  }
)

;; Milestone counters
(define-map project-milestone-counts
  { project-id: uint }
  { count: uint }
)

;; Utility Functions

;; Get current block height as timestamp
(define-private (get-block-timestamp)
  stacks-block-height
)

;; Validate impact category
(define-private (is-valid-category (category uint))
  (and (>= category u1) (<= category u6))
)

;; Validate project ID
(define-private (is-valid-project-id (project-id uint))
  (and (> project-id u0) (<= project-id MAX_PROJECT_ID))
)

;; Validate record ID
(define-private (is-valid-record-id (record-id uint))
  (and (> record-id u0) (<= record-id MAX_RECORD_ID))
)

;; Validate milestone ID
(define-private (is-valid-milestone-id (milestone-id uint))
  (and (> milestone-id u0) (<= milestone-id MAX_MILESTONE_ID))
)

;; Validate fee amount
(define-private (is-valid-fee (fee uint))
  (and (> fee u0) (<= fee MAX_FEE))
)

;; Validate stake amount
(define-private (is-valid-stake-amount (amount uint))
  (and (> amount u0) (<= amount MAX_STAKE))
)

;; Validate reward amount
(define-private (is-valid-reward-amount (amount uint))
  (<= amount MAX_REWARD)
)

;; Validate string is not empty
(define-private (is-non-empty-string-ascii (str (string-ascii 100)))
  (> (len str) u0)
)

;; Validate UTF8 string is not empty
(define-private (is-non-empty-string-utf8 (str (string-utf8 500)))
  (> (len str) u0)
)

;; Validate UTF8 200 string is not empty
(define-private (is-non-empty-string-utf8-200 (str (string-utf8 200)))
  (> (len str) u0)
)

;; Validate evidence hash
(define-private (is-valid-evidence-hash (hash (string-ascii 64)))
  (and (> (len hash) u0) (<= (len hash) u64))
)

;; Calculate reputation score
(define-private (calculate-reputation (successful uint) (total uint))
  (if (is-eq total u0)
    u0
    (* (/ (* successful u100) total) u10)
  )
)

;; Administrative Functions

;; Update contract settings (owner only)
(define-public (update-verification-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-valid-fee new-fee) ERR_INVALID_INPUT)
    (var-set verification-fee new-fee)
    (ok true)
  )
)

(define-public (update-min-stake-amount (new-amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-valid-stake-amount new-amount) ERR_INVALID_INPUT)
    (var-set min-stake-amount new-amount)
    (ok true)
  )
)

(define-public (toggle-contract-active)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set contract-active (not (var-get contract-active)))
    (ok (var-get contract-active))
  )
)


;; Impact Reporting Functions

;; Submit impact record
(define-public (submit-impact-record
  (project-id uint)
  (impact-value uint)
  (evidence-hash (string-ascii 64)))
  (let
    (
      (project (unwrap! (map-get? projects { project-id: project-id }) ERR_NOT_FOUND))
      (record-count (default-to u0 (get count (map-get? project-record-counts { project-id: project-id }))))
      (new-record-id (+ record-count u1))
    )
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
    (asserts! (is-valid-project-id project-id) ERR_INVALID_INPUT)
    (asserts! (> impact-value u0) ERR_INVALID_INPUT)
    (asserts! (is-valid-evidence-hash evidence-hash) ERR_INVALID_INPUT)
    (asserts! (get active project) ERR_INVALID_INPUT)
    (asserts! (or (is-eq tx-sender (get owner project)) 
                  (is-some (map-get? project-stakeholders { project-id: project-id, stakeholder: tx-sender })))
              ERR_UNAUTHORIZED)
    (asserts! (< (get-block-timestamp) (get expires-at project)) ERR_EXPIRED)
    (asserts! (<= new-record-id MAX_RECORD_ID) ERR_INVALID_INPUT)
    
    ;; Create impact record
    (map-set impact-records
      { project-id: project-id, record-id: new-record-id }
      {
        reporter: tx-sender,
        impact-value: impact-value,
        evidence-hash: evidence-hash,
        timestamp: (get-block-timestamp),
        verified: false,
        verifier: none
      }
    )
    
    ;; Update record count
    (map-set project-record-counts
      { project-id: project-id }
      { count: new-record-id }
    )
    
    (ok new-record-id)
  )
)

;; Verification System

;; Register as verifier
(define-public (register-verifier)
  (begin
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? verifiers { verifier: tx-sender })) ERR_ALREADY_EXISTS)
    
    ;; Pay verification registration fee
    (try! (stx-transfer? (var-get verification-fee) tx-sender CONTRACT_OWNER))
    
    (map-set verifiers
      { verifier: tx-sender }
      {
        reputation: u0,
        total-verifications: u0,
        successful-verifications: u0,
        registered-at: (get-block-timestamp),
        active: true
      }
    )
    
    (ok true)
  )
)

;; Verify impact record
(define-public (verify-impact-record (project-id uint) (record-id uint) (approved bool))
  (let
    (
      (verifier-data (unwrap! (map-get? verifiers { verifier: tx-sender }) ERR_UNAUTHORIZED))
      (record (unwrap! (map-get? impact-records { project-id: project-id, record-id: record-id }) ERR_NOT_FOUND))
      (project (unwrap! (map-get? projects { project-id: project-id }) ERR_NOT_FOUND))
    )
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
    (asserts! (is-valid-project-id project-id) ERR_INVALID_INPUT)
    (asserts! (is-valid-record-id record-id) ERR_INVALID_INPUT)
    (asserts! (get active verifier-data) ERR_UNAUTHORIZED)
    (asserts! (not (get verified record)) ERR_ALREADY_EXISTS)
    
    ;; Update impact record
    (map-set impact-records
      { project-id: project-id, record-id: record-id }
      (merge record {
        verified: approved,
        verifier: (some tx-sender)
      })
    )
    
    ;; If approved, update project impact
    (if approved
      (map-set projects
        { project-id: project-id }
        (merge project {
          current-impact: (+ (get current-impact project) (get impact-value record))
        })
      )
      true
    )
    
    ;; Update verifier statistics
    (map-set verifiers
      { verifier: tx-sender }
      (merge verifier-data {
        total-verifications: (+ (get total-verifications verifier-data) u1),
        successful-verifications: (if approved 
                                    (+ (get successful-verifications verifier-data) u1)
                                    (get successful-verifications verifier-data)),
        reputation: (calculate-reputation 
                      (if approved 
                        (+ (get successful-verifications verifier-data) u1)
                        (get successful-verifications verifier-data))
                      (+ (get total-verifications verifier-data) u1))
      })
    )
    
    (ok approved)
  )
)

