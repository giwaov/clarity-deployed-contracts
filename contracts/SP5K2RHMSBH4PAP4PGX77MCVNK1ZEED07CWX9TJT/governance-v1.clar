;; Governance Contract
;; Decentralized governance for TimeLock Exchange
;; Enables proposal creation, voting, and execution

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-invalid-proposal (err u102))
(define-constant err-proposal-not-found (err u103))
(define-constant err-voting-closed (err u104))
(define-constant err-already-voted (err u105))
(define-constant err-insufficient-voting-power (err u106))
(define-constant err-proposal-not-ready (err u107))
(define-constant err-proposal-defeated (err u108))
(define-constant err-proposal-already-executed (err u109))
(define-constant err-quorum-not-met (err u110))
(define-constant err-invalid-duration (err u111))

;; Governance parameters
(define-data-var min-proposal-threshold uint u100000000) ;; 100 STX minimum to create proposal
(define-data-var voting-period uint u10080) ;; ~7 days in blocks
(define-data-var execution-delay uint u1440) ;; ~1 day delay after voting ends
(define-data-var quorum-percentage uint u4) ;; 4% of total supply needed
(define-data-var proposal-count uint u0)
(define-data-var total-voting-power uint u0)

;; Proposal states
(define-constant STATE_PENDING u0)
(define-constant STATE_ACTIVE u1)
(define-constant STATE_DEFEATED u2)
(define-constant STATE_SUCCEEDED u3)
(define-constant STATE_QUEUED u4)
(define-constant STATE_EXECUTED u5)
(define-constant STATE_CANCELLED u6)

;; Proposal types
(define-constant TYPE_PARAMETER_CHANGE u1)
(define-constant TYPE_CONTRACT_UPGRADE u2)
(define-constant TYPE_TREASURY_SPEND u3)
(define-constant TYPE_EMERGENCY_ACTION u4)

;; Proposals
(define-map proposals
  { proposal-id: uint }
  {
    proposer: principal,
    title: (string-ascii 128),
    description: (string-utf8 1024),
    proposal-type: uint,
    start-block: uint,
    end-block: uint,
    for-votes: uint,
    against-votes: uint,
    abstain-votes: uint,
    state: uint,
    execution-eta: uint,
    executed: bool,
    cancelled: bool,
    target-contract: (optional principal),
    call-data: (optional (buff 256))
  }
)

;; Vote records
(define-map votes
  { proposal-id: uint, voter: principal }
  {
    support: uint, ;; 0 = against, 1 = for, 2 = abstain
    voting-power: uint,
    block-height: uint
  }
)

;; Voting power (can be based on staked tokens or locked positions)
(define-map voting-power
  { address: principal }
  {
    power: uint,
    delegated-to: (optional principal),
    delegated-power: uint
  }
)

;; Delegation tracking
(define-map delegations
  { delegator: principal }
  { delegate: principal }
)

;; Proposal actions for execution
(define-map proposal-actions
  { proposal-id: uint, action-index: uint }
  {
    target: principal,
    value: uint,
    signature: (string-ascii 64),
    data: (buff 256)
  }
)

(define-map proposal-action-count
  { proposal-id: uint }
  { count: uint }
)

;; Events tracking
(define-map governance-events
  { event-id: uint }
  {
    event-type: (string-ascii 32),
    proposal-id: uint,
    actor: principal,
    block-height: uint,
    data: (optional (buff 128))
  }
)

(define-data-var event-count uint u0)

;; Read-only functions

;; Get proposal
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

;; Get vote
(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter })
)

;; Get voting power for address
(define-read-only (get-voting-power (address principal))
  (default-to { power: u0, delegated-to: none, delegated-power: u0 }
    (map-get? voting-power { address: address }))
)

;; Get effective voting power (including delegations)
(define-read-only (get-effective-voting-power (address principal))
  (let (
    (own-power (get power (get-voting-power address)))
    (delegated (get delegated-power (get-voting-power address)))
    (delegation (map-get? delegations { delegator: address }))
  )
    (if (is-some delegation)
      delegated ;; If delegated, only count delegated power received
      (+ own-power delegated)
    )
  )
)

;; Calculate proposal state
(define-read-only (get-proposal-state (proposal-id uint))
  (match (map-get? proposals { proposal-id: proposal-id })
    proposal
      (if (get cancelled proposal)
        STATE_CANCELLED
        (if (get executed proposal)
          STATE_EXECUTED
          (if (< stacks-block-height (get start-block proposal))
            STATE_PENDING
            (if (<= stacks-block-height (get end-block proposal))
              STATE_ACTIVE
              (if (proposal-succeeded proposal)
                (if (>= stacks-block-height (get execution-eta proposal))
                  STATE_QUEUED
                  STATE_SUCCEEDED
                )
                STATE_DEFEATED
              )
            )
          )
        )
      )
    STATE_PENDING
  )
)

;; Check if proposal succeeded
(define-read-only (proposal-succeeded (proposal {
  proposer: principal,
  title: (string-ascii 128),
  description: (string-utf8 1024),
  proposal-type: uint,
  start-block: uint,
  end-block: uint,
  for-votes: uint,
  against-votes: uint,
  abstain-votes: uint,
  state: uint,
  execution-eta: uint,
  executed: bool,
  cancelled: bool,
  target-contract: (optional principal),
  call-data: (optional (buff 256))
}))
  (let (
    (total-votes (+ (get for-votes proposal) (get against-votes proposal)))
    (quorum-needed (/ (* (var-get total-voting-power) (var-get quorum-percentage)) u100))
  )
    (and
      (> (get for-votes proposal) (get against-votes proposal))
      (>= total-votes quorum-needed)
    )
  )
)

;; Get proposal results
(define-read-only (get-proposal-results (proposal-id uint))
  (match (map-get? proposals { proposal-id: proposal-id })
    proposal
      (ok {
        for-votes: (get for-votes proposal),
        against-votes: (get against-votes proposal),
        abstain-votes: (get abstain-votes proposal),
        total-votes: (+ (+ (get for-votes proposal) (get against-votes proposal)) (get abstain-votes proposal)),
        quorum-reached: (>= (+ (get for-votes proposal) (get against-votes proposal)) 
          (/ (* (var-get total-voting-power) (var-get quorum-percentage)) u100)),
        passed: (proposal-succeeded proposal)
      })
    (err err-proposal-not-found)
  )
)

;; Check if address has voted
(define-read-only (has-voted (proposal-id uint) (voter principal))
  (is-some (map-get? votes { proposal-id: proposal-id, voter: voter }))
)

;; Get governance parameters
(define-read-only (get-governance-params)
  {
    min-proposal-threshold: (var-get min-proposal-threshold),
    voting-period: (var-get voting-period),
    execution-delay: (var-get execution-delay),
    quorum-percentage: (var-get quorum-percentage),
    total-voting-power: (var-get total-voting-power)
  }
)

;; Public functions

;; Register voting power (called by staking contract)
(define-public (register-voting-power (amount uint))
  (let (
    (current (get-voting-power tx-sender))
    (new-power (+ (get power current) amount))
  )
    (map-set voting-power
      { address: tx-sender }
      (merge current { power: new-power })
    )
    (var-set total-voting-power (+ (var-get total-voting-power) amount))
    (ok new-power)
  )
)

;; Remove voting power (called when unstaking)
(define-public (remove-voting-power (amount uint))
  (let (
    (current (get-voting-power tx-sender))
    (current-power (get power current))
  )
    (asserts! (>= current-power amount) err-insufficient-voting-power)
    (map-set voting-power
      { address: tx-sender }
      (merge current { power: (- current-power amount) })
    )
    (var-set total-voting-power (- (var-get total-voting-power) amount))
    (ok (- current-power amount))
  )
)

;; Delegate voting power
(define-public (delegate (delegate-to principal))
  (let (
    (delegator-power (get-voting-power tx-sender))
    (delegate-power (get-voting-power delegate-to))
  )
    ;; Set delegation
    (map-set delegations
      { delegator: tx-sender }
      { delegate: delegate-to }
    )
    
    ;; Update delegator
    (map-set voting-power
      { address: tx-sender }
      (merge delegator-power { delegated-to: (some delegate-to) })
    )
    
    ;; Update delegate's delegated power
    (map-set voting-power
      { address: delegate-to }
      (merge delegate-power { 
        delegated-power: (+ (get delegated-power delegate-power) (get power delegator-power))
      })
    )
    
    (ok delegate-to)
  )
)

;; Remove delegation
(define-public (undelegate)
  (let (
    (delegation (unwrap! (map-get? delegations { delegator: tx-sender }) err-not-authorized))
    (delegate-to (get delegate delegation))
    (delegator-power (get-voting-power tx-sender))
    (delegate-power (get-voting-power delegate-to))
  )
    ;; Remove delegation record
    (map-delete delegations { delegator: tx-sender })
    
    ;; Update delegator
    (map-set voting-power
      { address: tx-sender }
      (merge delegator-power { delegated-to: none })
    )
    
    ;; Update delegate's delegated power
    (map-set voting-power
      { address: delegate-to }
      (merge delegate-power {
        delegated-power: (- (get delegated-power delegate-power) (get power delegator-power))
      })
    )
    
    (ok true)
  )
)

;; Create proposal
(define-public (create-proposal 
  (title (string-ascii 128))
  (description (string-utf8 1024))
  (proposal-type uint)
  (target-contract (optional principal))
  (call-data (optional (buff 256)))
)
  (let (
    (proposer-power (get-effective-voting-power tx-sender))
    (proposal-id (+ (var-get proposal-count) u1))
    (start-block (+ stacks-block-height u1))
    (end-block (+ start-block (var-get voting-period)))
  )
    ;; Check voting power threshold
    (asserts! (>= proposer-power (var-get min-proposal-threshold)) err-insufficient-voting-power)
    ;; Validate proposal type
    (asserts! (and (>= proposal-type u1) (<= proposal-type u4)) err-invalid-proposal)
    
    ;; Create proposal
    (map-set proposals
      { proposal-id: proposal-id }
      {
        proposer: tx-sender,
        title: title,
        description: description,
        proposal-type: proposal-type,
        start-block: start-block,
        end-block: end-block,
        for-votes: u0,
        against-votes: u0,
        abstain-votes: u0,
        state: STATE_PENDING,
        execution-eta: (+ end-block (var-get execution-delay)),
        executed: false,
        cancelled: false,
        target-contract: target-contract,
        call-data: call-data
      }
    )
    
    ;; Update proposal count
    (var-set proposal-count proposal-id)
    
    ;; Record event
    (record-event "proposal-created" proposal-id tx-sender none)
    
    (ok proposal-id)
  )
)

;; Cast vote
(define-public (cast-vote (proposal-id uint) (support uint))
  (let (
    (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) err-proposal-not-found))
    (voter-power (get-effective-voting-power tx-sender))
  )
    ;; Check voting is active
    (asserts! (>= stacks-block-height (get start-block proposal)) err-voting-closed)
    (asserts! (<= stacks-block-height (get end-block proposal)) err-voting-closed)
    ;; Check not already voted
    (asserts! (not (has-voted proposal-id tx-sender)) err-already-voted)
    ;; Check has voting power
    (asserts! (> voter-power u0) err-insufficient-voting-power)
    ;; Validate support value
    (asserts! (<= support u2) err-invalid-proposal)
    
    ;; Record vote
    (map-set votes
      { proposal-id: proposal-id, voter: tx-sender }
      {
        support: support,
        voting-power: voter-power,
        block-height: stacks-block-height
      }
    )
    
    ;; Update proposal vote counts
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal
        (if (is-eq support u1)
          { for-votes: (+ (get for-votes proposal) voter-power), against-votes: (get against-votes proposal), abstain-votes: (get abstain-votes proposal) }
          (if (is-eq support u0)
            { for-votes: (get for-votes proposal), against-votes: (+ (get against-votes proposal) voter-power), abstain-votes: (get abstain-votes proposal) }
            { for-votes: (get for-votes proposal), against-votes: (get against-votes proposal), abstain-votes: (+ (get abstain-votes proposal) voter-power) }
          )
        )
      )
    )
    
    ;; Record event
    (record-event "vote-cast" proposal-id tx-sender none)
    
    (ok { proposal-id: proposal-id, support: support, power: voter-power })
  )
)

;; Queue proposal for execution
(define-public (queue-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) err-proposal-not-found))
    (state (get-proposal-state proposal-id))
  )
    ;; Must be succeeded
    (asserts! (is-eq state STATE_SUCCEEDED) err-proposal-not-ready)
    
    ;; Update state
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { state: STATE_QUEUED })
    )
    
    ;; Record event
    (record-event "proposal-queued" proposal-id tx-sender none)
    
    (ok (get execution-eta proposal))
  )
)

;; Execute proposal
(define-public (execute-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) err-proposal-not-found))
    (state (get-proposal-state proposal-id))
  )
    ;; Must be queued and ready
    (asserts! (is-eq state STATE_QUEUED) err-proposal-not-ready)
    (asserts! (>= stacks-block-height (get execution-eta proposal)) err-proposal-not-ready)
    (asserts! (not (get executed proposal)) err-proposal-already-executed)
    
    ;; Mark as executed
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { executed: true, state: STATE_EXECUTED })
    )
    
    ;; Record event
    (record-event "proposal-executed" proposal-id tx-sender none)
    
    ;; Note: Actual execution logic would call target contract
    ;; This is a simplified version
    
    (ok true)
  )
)

;; Cancel proposal (only proposer or admin)
(define-public (cancel-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) err-proposal-not-found))
  )
    ;; Only proposer or owner can cancel
    (asserts! (or (is-eq tx-sender (get proposer proposal)) (is-eq tx-sender contract-owner)) err-not-authorized)
    ;; Cannot cancel if executed
    (asserts! (not (get executed proposal)) err-proposal-already-executed)
    
    ;; Cancel
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { cancelled: true, state: STATE_CANCELLED })
    )
    
    ;; Record event
    (record-event "proposal-cancelled" proposal-id tx-sender none)
    
    (ok true)
  )
)

;; Admin functions

;; Update voting period
(define-public (set-voting-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (>= new-period u1440) err-invalid-duration) ;; Minimum 1 day
    (var-set voting-period new-period)
    (ok new-period)
  )
)

;; Update quorum
(define-public (set-quorum (new-quorum uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (and (>= new-quorum u1) (<= new-quorum u50)) err-invalid-proposal) ;; 1-50%
    (var-set quorum-percentage new-quorum)
    (ok new-quorum)
  )
)

;; Update proposal threshold
(define-public (set-proposal-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set min-proposal-threshold new-threshold)
    (ok new-threshold)
  )
)

;; Private functions

;; Record governance event
(define-private (record-event 
  (event-type (string-ascii 32))
  (proposal-id uint)
  (actor principal)
  (data (optional (buff 128)))
)
  (let (
    (event-id (+ (var-get event-count) u1))
  )
    (map-set governance-events
      { event-id: event-id }
      {
        event-type: event-type,
        proposal-id: proposal-id,
        actor: actor,
        block-height: stacks-block-height,
        data: data
      }
    )
    (var-set event-count event-id)
    true
  )
)
