;; title: stake-reputation
;; version:
;; summary:
;; description:

;;  Stakra - Enhanced Reputation Protocol Smart Contract
;; A comprehensive system for managing participant reputation with staking and governance

;; Error Definitions
;; Governance and access control errors (1xx range)
(define-constant ERR-ACCESS-DENIED (err u100))
(define-constant ERR-GOVERNANCE-DISABLED (err u101))
(define-constant ERR-PROPOSAL-EXISTS (err u102))

;; Validation and bounds errors (2xx range)
(define-constant ERR-VALIDATION-FAILED (err u200))
(define-constant ERR-BOUNDS-VIOLATION (err u201))
(define-constant ERR-THRESHOLD-UNMET (err u202))

;; Entity state errors (3xx range)
(define-constant ERR-ENTITY-NOT-FOUND (err u300))
(define-constant ERR-ENTITY-EXISTS (err u301))
(define-constant ERR-INVALID-STATE (err u302))

;; Economic constraints errors (4xx range)
(define-constant ERR-INSUFFICIENT-FUNDS (err u400))
(define-constant ERR-ECONOMIC-CONSTRAINT (err u401))

;; Protocol Constants
;; Reputation bounds
(define-constant REPUTATION-MINIMUM u0)
(define-constant REPUTATION-MAXIMUM u100)

;; Time-based constants
(define-constant EPOCH-LENGTH u144) ;; Approximately 1 day in blocks
(define-constant DECAY-INTERVAL u10000)
(define-constant DECAY-RATE u5)

;; Governance parameters
(define-constant PROPOSAL-THRESHOLD u75)
(define-constant VOTING-PERIOD u1008) ;; ~1 week in blocks

;; Economic parameters
(define-constant MINIMUM-COLLATERAL-REQUIREMENT u1000)
(define-constant COLLATERAL-MULTIPLIER u2)
(define-constant PENALTY-RATE u10)

;; Protocol State Variables
;; Administrative state
(define-data-var protocol-administrator principal tx-sender)
(define-data-var governance-enabled bool true)
(define-data-var protocol-parameters {
  min-reputation: uint,
  max-reputation: uint,
  collateral-requirement: uint,
  epoch-length: uint,
} {
  min-reputation: REPUTATION-MINIMUM,
  max-reputation: REPUTATION-MAXIMUM,
  collateral-requirement: MINIMUM-COLLATERAL-REQUIREMENT,
  epoch-length: EPOCH-LENGTH,
})

;; Protocol metrics
(define-data-var global-statistics {
  participant-count: uint,
  total-collateral: uint,
  total-evaluations: uint,
  current-epoch: uint,
} {
  participant-count: u0,
  total-collateral: u0,
  total-evaluations: u0,
  current-epoch: u0,
})

;; Data Maps
;; Participant core data
(define-map participant-registry
  principal
  {
    reputation-score: uint,
    last-active-epoch: uint,
    evaluation-count: uint,
    collateral-balance: uint,
    status: (string-ascii 20), ;; "ACTIVE", "SUSPENDED", "PROBATION"
  }
)

;; Evaluation and history tracking
(define-map evaluation-ledger
  {
    participant: principal,
    epoch: uint,
  }
  {
    base-score: uint,
    weighted-score: uint,
    evaluator: principal,
    timestamp: uint,
    metadata: (optional (string-utf8 100)),
  }
)

;; Evaluator authorization and reputation
(define-map evaluator-credentials
  principal
  {
    authorization-status: bool,
    evaluation-count: uint,
    accuracy-score: uint,
    last-evaluation: uint,
  }
)

;; Governance proposals and voting
(define-map governance-proposals
  uint ;; proposal-id
  {
    proposer: principal,
    description: (string-utf8 500),
    start-block: uint,
    end-block: uint,
    status: (string-ascii 10), ;; "ACTIVE", "PASSED", "FAILED", "EXECUTED"
    votes-for: uint,
    votes-against: uint,
    execution-payload: (optional (buff 1024)),
  }
)

(define-private (validate-participant-data (participant-data {
  reputation-score: uint,
  last-active-epoch: uint,
  evaluation-count: uint,
  collateral-balance: uint,
  status: (string-ascii 20),
}))
  (if (and
      (validate-reputation-bounds (get reputation-score participant-data))
      (>= (get collateral-balance participant-data)
        MINIMUM-COLLATERAL-REQUIREMENT
      )
      (or
        (is-eq (get status participant-data) "ACTIVE")
        (is-eq (get status participant-data) "SUSPENDED")
        (is-eq (get status participant-data) "PROBATION")
      )
    )
    (ok participant-data) ;; Return validated data instead of just true
    ERR-VALIDATION-FAILED
  )
)

(define-private (validate-metadata (metadata (optional (string-utf8 100))))
  (match metadata
    meta
    (if (< (len meta) u100)
      (ok metadata) ;; Return validated metadata
      ERR-VALIDATION-FAILED
    )
    (ok none) ;; None is always valid
  )
)

(define-private (calculate-weighted-reputation
    (current-score uint)
    (new-score uint)
    (evaluation-count uint)
    (evaluator-accuracy uint)
  )
  (let (
      (base-weight (/ (* current-score evaluation-count) (+ evaluation-count u1)))
      (new-weight (/ (* new-score evaluator-accuracy) (* u100 (+ evaluation-count u1))))
    )
    (+ base-weight new-weight)
  )
)

;; Private Functions
;; Validation functions
(define-private (validate-reputation-bounds (score uint))
  (let ((params (var-get protocol-parameters)))
    (and
      (>= score (get min-reputation params))
      (<= score (get max-reputation params))
    )
  )
)
