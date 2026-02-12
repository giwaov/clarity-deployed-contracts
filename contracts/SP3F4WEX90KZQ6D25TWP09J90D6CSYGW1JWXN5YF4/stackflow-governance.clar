;; StackFlow Governance Contract
;; Community-driven governance for the StackFlow ecosystem
;; FLOW holders can submit proposals and vote on protocol changes

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u300))
(define-constant err-not-found (err u301))
(define-constant err-already-voted (err u302))
(define-constant err-insufficient-flow (err u303))
(define-constant err-proposal-expired (err u304))
(define-constant err-proposal-not-passed (err u305))
(define-constant err-already-executed (err u306))
(define-constant err-voting-closed (err u307))
(define-constant err-invalid-proposal (err u308))

;; Token references
(define-constant flow-token 'SP3F4WEX90KZQ6D25TWP09J90D6CSYGW1JWXN5YF4.stackflow-flow-token)
(define-constant staking-contract 'SP3F4WEX90KZQ6D25TWP09J90D6CSYGW1JWXN5YF4.stackflow-staking)

;; Governance parameters
(define-constant min-proposal-stake u5000000000) ;; 5,000 FLOW required to submit proposal
(define-constant voting-period u1440) ;; ~10 days in blocks (assuming 10 min blocks)
(define-constant quorum-threshold u10000000000) ;; 10,000 FLOW minimum participation
(define-constant approval-threshold u6000) ;; 60% approval required (basis points)

;; State
(define-data-var proposal-nonce uint u0)
(define-data-var paused bool false)

;; Proposal types
(define-constant proposal-type-parameter "PARAM")
(define-constant proposal-type-strategy "STRATEGY")
(define-constant proposal-type-treasury "TREASURY")
(define-constant proposal-type-upgrade "UPGRADE")

;; Proposals
(define-map proposals uint {
  proposer: principal,
  title: (string-utf8 256),
  description: (string-utf8 1024),
  proposal-type: (string-ascii 8),
  parameter: (optional (string-ascii 32)),
  new-value: (optional uint),
  created-at: uint,
  voting-ends-at: uint,
  votes-for: uint,
  votes-against: uint,
  total-votes: uint,
  is-executed: bool,
  execution-block: (optional uint)
})

;; Track who voted on what
(define-map votes {proposal-id: uint, voter: principal} {
  vote-power: uint,
  voted-for: bool
})

;; Read-only: Get proposal
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id))

;; Read-only: Get user's vote on a proposal
(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes {proposal-id: proposal-id, voter: voter}))

;; Read-only: Check if proposal passed
(define-read-only (has-proposal-passed (proposal-id uint))
  (match (get-proposal proposal-id)
    proposal
      (let (
        (total (get total-votes proposal))
        (for (get votes-for proposal))
        (against (get votes-against proposal))
      )
        (ok (and
          (>= total quorum-threshold) ;; Quorum met
          (>= (/ (* for u10000) (+ for against)) approval-threshold)))) ;; Approval threshold met
    (err err-not-found)))

;; Submit a proposal
(define-public (submit-proposal 
    (title (string-utf8 256))
    (description (string-utf8 1024))
    (proposal-type (string-ascii 8))
    (parameter (optional (string-ascii 32)))
    (new-value (optional uint)))
  (let (
    (proposer tx-sender)
    (proposal-id (+ (var-get proposal-nonce) u1))
    (stake-info (contract-call? staking-contract get-stake proposer))
    (voting-power (match stake-info data (get amount data) u0))
  )
    (asserts! (not (var-get paused)) err-owner-only)
    (asserts! (>= voting-power min-proposal-stake) err-insufficient-flow)
    
    ;; Create proposal
    (map-set proposals proposal-id {
      proposer: proposer,
      title: title,
      description: description,
      proposal-type: proposal-type,
      parameter: parameter,
      new-value: new-value,
      created-at: stacks-block-height,
      voting-ends-at: (+ stacks-block-height voting-period),
      votes-for: u0,
      votes-against: u0,
      total-votes: u0,
      is-executed: false,
      execution-block: none
    })
    
    (var-set proposal-nonce proposal-id)
    
    (print {
      event: "proposal-submitted",
      proposal-id: proposal-id,
      proposer: proposer,
      title: title,
      type: proposal-type
    })
    
    (ok proposal-id)))

;; Vote on a proposal
(define-public (vote (proposal-id uint) (vote-for bool))
  (let (
    (voter tx-sender)
    (proposal (unwrap! (get-proposal proposal-id) err-not-found))
    (stake-info (contract-call? staking-contract get-stake voter))
    (voting-power (match stake-info data (get amount data) u0))
  )
    (asserts! (> voting-power u0) err-insufficient-flow)
    (asserts! (<= stacks-block-height (get voting-ends-at proposal)) err-voting-closed)
    (asserts! (is-none (get-vote proposal-id voter)) err-already-voted)
    
    ;; Record vote
    (map-set votes {proposal-id: proposal-id, voter: voter} {
      vote-power: voting-power,
      voted-for: vote-for
    })
    
    ;; Update proposal totals
    (map-set proposals proposal-id (merge proposal {
      votes-for: (if vote-for (+ (get votes-for proposal) voting-power) (get votes-for proposal)),
      votes-against: (if vote-for (get votes-against proposal) (+ (get votes-against proposal) voting-power)),
      total-votes: (+ (get total-votes proposal) voting-power)
    }))
    
    (print {
      event: "vote-cast",
      proposal-id: proposal-id,
      voter: voter,
      vote-for: vote-for,
      power: voting-power
    })
    
    (ok true)))

;; Execute a passed proposal (owner only for now, can be made permissionless)
(define-public (execute-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (get-proposal proposal-id) err-not-found))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> stacks-block-height (get voting-ends-at proposal)) err-voting-closed)
    (asserts! (not (get is-executed proposal)) err-already-executed)
    (asserts! (unwrap! (has-proposal-passed proposal-id) err-proposal-not-passed) err-proposal-not-passed)
    
    ;; Mark as executed
    (map-set proposals proposal-id (merge proposal {
      is-executed: true,
      execution-block: (some stacks-block-height)
    }))
    
    (print {
      event: "proposal-executed",
      proposal-id: proposal-id,
      type: (get proposal-type proposal)
    })
    
    ;; Note: Actual execution logic would be implemented based on proposal type
    ;; For now, this marks it as executed for governance tracking
    (ok true)))

;; Read-only utilities

(define-read-only (get-governance-stats)
  (ok {
    total-proposals: (var-get proposal-nonce),
    min-proposal-stake: min-proposal-stake,
    voting-period: voting-period,
    quorum-threshold: quorum-threshold,
    approval-threshold: approval-threshold,
    paused: (var-get paused)
  }))

(define-read-only (get-active-proposals)
  ;; Returns count of non-expired proposals
  (ok (var-get proposal-nonce)))

;; Admin functions

(define-public (pause-governance)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set paused true)
    (print {event: "governance-paused"})
    (ok true)))

(define-public (unpause-governance)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set paused false)
    (print {event: "governance-unpaused"})
    (ok true)))
