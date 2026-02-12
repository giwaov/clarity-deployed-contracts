;; BitTrust Governance Contract
;; Platform governance and parameter management

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u300))
(define-constant err-not-found (err u301))
(define-constant err-unauthorized (err u302))
(define-constant err-already-voted (err u303))
(define-constant err-proposal-not-active (err u304))
(define-constant err-proposal-not-passed (err u305))

;; Data Variables
(define-data-var proposal-nonce uint u0)
(define-data-var voting-period uint u1440) ;; ~10 days in blocks
(define-data-var quorum-threshold uint u1000) ;; 10% in basis points
(define-data-var platform-paused bool false)

;; Data Maps
(define-map proposals
  { proposal-id: uint }
  {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-utf8 500),
    parameter: (string-ascii 50),
    new-value: uint,
    votes-for: uint,
    votes-against: uint,
    start-block: uint,
    end-block: uint,
    executed: bool,
    status: (string-ascii 20) ;; "active", "passed", "rejected", "executed"
  }
)

(define-map votes
  { proposal-id: uint, voter: principal }
  {
    vote: bool, ;; true = for, false = against
    weight: uint
  }
)

(define-map platform-parameters
  { parameter: (string-ascii 50) }
  { value: uint }
)

;; Initialize default parameters
(map-set platform-parameters { parameter: "min-collateral-ratio" } { value: u100 })
(map-set platform-parameters { parameter: "max-interest-rate" } { value: u5000 })
(map-set platform-parameters { parameter: "platform-fee" } { value: u250 })

;; Read-only functions
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-parameter (parameter (string-ascii 50)))
  (default-to { value: u0 } (map-get? platform-parameters { parameter: parameter }))
)

(define-read-only (is-platform-paused)
  (var-get platform-paused)
)

(define-read-only (can-execute-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (get-proposal proposal-id) (err err-not-found)))
      (total-votes (+ (get votes-for proposal) (get votes-against proposal)))
      (quorum (var-get quorum-threshold))
    )
    (ok (and
      (is-eq (get status proposal) "passed")
      (not (get executed proposal))
      (> stacks-block-height (get end-block proposal))
      (>= (* total-votes u10000) quorum)
    ))
  )
)

;; Public functions

;; Create a governance proposal
(define-public (create-proposal 
  (title (string-ascii 100))
  (description (string-utf8 500))
  (parameter (string-ascii 50))
  (new-value uint))
  (let
    (
      (proposal-id (var-get proposal-nonce))
      (voting-duration (var-get voting-period))
    )
    (map-set proposals
      { proposal-id: proposal-id }
      {
        proposer: tx-sender,
        title: title,
        description: description,
        parameter: parameter,
        new-value: new-value,
        votes-for: u0,
        votes-against: u0,
        start-block: stacks-block-height,
        end-block: (+ stacks-block-height voting-duration),
        executed: false,
        status: "active"
      }
    )
    (var-set proposal-nonce (+ proposal-id u1))
    (ok proposal-id)
  )
)

;; Vote on a proposal
(define-public (vote (proposal-id uint) (vote-for bool))
  (let
    (
      (proposal (unwrap! (get-proposal proposal-id) err-not-found))
      (existing-vote (map-get? votes { proposal-id: proposal-id, voter: tx-sender }))
      (vote-weight u1) ;; Could be based on reputation or token holdings
    )
    (asserts! (is-none existing-vote) err-already-voted)
    (asserts! (is-eq (get status proposal) "active") err-proposal-not-active)
    (asserts! (<= stacks-block-height (get end-block proposal)) err-proposal-not-active)
    
    ;; Record vote
    (map-set votes
      { proposal-id: proposal-id, voter: tx-sender }
      { vote: vote-for, weight: vote-weight }
    )
    
    ;; Update proposal vote counts
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal {
        votes-for: (if vote-for (+ (get votes-for proposal) vote-weight) (get votes-for proposal)),
        votes-against: (if vote-for (get votes-against proposal) (+ (get votes-against proposal) vote-weight))
      })
    )
    
    (ok true)
  )
)

;; Finalize proposal after voting period
(define-public (finalize-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (get-proposal proposal-id) err-not-found))
      (votes-for (get votes-for proposal))
      (votes-against (get votes-against proposal))
    )
    (asserts! (is-eq (get status proposal) "active") err-proposal-not-active)
    (asserts! (> stacks-block-height (get end-block proposal)) err-proposal-not-active)
    
    ;; Determine outcome
    (let
      (
        (passed (> votes-for votes-against))
        (new-status (if passed "passed" "rejected"))
      )
      (map-set proposals
        { proposal-id: proposal-id }
        (merge proposal { status: new-status })
      )
      (ok passed)
    )
  )
)

;; Execute a passed proposal
(define-public (execute-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (get-proposal proposal-id) err-not-found))
    )
    (asserts! (unwrap! (can-execute-proposal proposal-id) err-not-found) err-proposal-not-passed)
    
    ;; Update parameter
    (map-set platform-parameters
      { parameter: (get parameter proposal) }
      { value: (get new-value proposal) }
    )
    
    ;; Mark as executed
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { executed: true, status: "executed" })
    )
    
    (ok true)
  )
)

;; Emergency pause (owner only)
(define-public (pause-platform)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set platform-paused true)
    (ok true)
  )
)

;; Unpause platform (owner only)
(define-public (unpause-platform)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set platform-paused false)
    (ok true)
  )
)

;; Update voting period (owner only)
(define-public (set-voting-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set voting-period new-period)
    (ok true)
  )
)
