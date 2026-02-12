;; title: ProtoFlux
;; version:
;; summary:
;; description:

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u404))
(define-constant ERR_PROPOSAL_EXPIRED (err u405))
(define-constant ERR_PROPOSAL_EXECUTED (err u406))
(define-constant ERR_ALREADY_VOTED (err u407))
(define-constant ERR_VOTING_PERIOD_ACTIVE (err u408))
(define-constant ERR_INSUFFICIENT_VOTES (err u409))

;; Data variables
(define-data-var proposal-counter uint u0)
(define-data-var voting-period uint u1008) ;; ~1 week in blocks
(define-data-var quorum-threshold uint u50) ;; 50% participation required
(define-data-var approval-threshold uint u60) ;; 60% approval required

;; Data maps
(define-map proposals
  uint
  {
    proposer: principal,
    title: (string-ascii 256),
    description: (string-ascii 1024),
    new-contract-address: principal,
    created-at: uint,
    executed: bool,
    yes-votes: uint,
    no-votes: uint,
    total-voters: uint,
  }
)

(define-map votes
  {
    proposal-id: uint,
    voter: principal,
  }
  {
    vote: bool,
    block-height: uint,
  }
)

(define-map voter-weights
  principal
  uint
)

;; Public functions

;; Create a new upgrade proposal
(define-public (create-proposal
    (title (string-ascii 256))
    (description (string-ascii 1024))
    (new-contract-address principal)
  )
  (let ((proposal-id (+ (var-get proposal-counter) u1)))
    (map-set proposals proposal-id {
      proposer: tx-sender,
      title: title,
      description: description,
      new-contract-address: new-contract-address,
      created-at: stacks-block-height,
      executed: false,
      yes-votes: u0,
      no-votes: u0,
      total-voters: u0,
    })
    (var-set proposal-counter proposal-id)
    (ok proposal-id)
  )
)

;; Vote on a proposal
(define-public (vote
    (proposal-id uint)
    (support bool)
  )
  (let (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (voter-weight (default-to u1 (map-get? voter-weights tx-sender)))
      (existing-vote (map-get? votes {
        proposal-id: proposal-id,
        voter: tx-sender,
      }))
    )
    ;; Check if proposal is still active
    (asserts!
      (< stacks-block-height
        (+ (get created-at proposal) (var-get voting-period))
      )
      ERR_PROPOSAL_EXPIRED
    )

    ;; Check if proposal is not executed
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_EXECUTED)

    ;; Check if voter hasn't voted already
    (asserts! (is-none existing-vote) ERR_ALREADY_VOTED)

    ;; Record the vote
    (map-set votes {
      proposal-id: proposal-id,
      voter: tx-sender,
    } {
      vote: support,
      block-height: stacks-block-height,
    })

    ;; Update proposal vote counts
    (map-set proposals proposal-id
      (merge proposal {
        yes-votes: (if support
          (+ (get yes-votes proposal) voter-weight)
          (get yes-votes proposal)
        ),
        no-votes: (if support
          (get no-votes proposal)
          (+ (get no-votes proposal) voter-weight)
        ),
        total-voters: (+ (get total-voters proposal) u1),
      })
    )

    (ok true)
  )
)

;; Execute a proposal if it passes
(define-public (execute-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND)))
    ;; Check if voting period has ended
    (asserts!
      (>= stacks-block-height
        (+ (get created-at proposal) (var-get voting-period))
      )
      ERR_VOTING_PERIOD_ACTIVE
    )

    ;; Check if proposal is not already executed
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_EXECUTED)

    ;; Check quorum (minimum participation)
    (let (
        (total-weight (get-total-voting-weight))
        (participated-weight (+ (get yes-votes proposal) (get no-votes proposal)))
      )
      (asserts!
        (>= (* participated-weight u100)
          (* total-weight (var-get quorum-threshold))
        )
        ERR_INSUFFICIENT_VOTES
      )

      ;; Check approval threshold
      (asserts!
        (>= (* (get yes-votes proposal) u100)
          (* participated-weight (var-get approval-threshold))
        )
        ERR_INSUFFICIENT_VOTES
      )

      ;; Mark as executed
      (map-set proposals proposal-id (merge proposal { executed: true }))

      ;; In a real implementation, this would trigger the contract upgrade
      ;; For now, we just emit the success
      (print {
        event: "proposal-executed",
        proposal-id: proposal-id,
        new-contract: (get new-contract-address proposal),
      })

      (ok true)
    )
  )
)

;; Admin function to set voter weight
(define-public (set-voter-weight
    (voter principal)
    (weight uint)
  )
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set voter-weights voter weight)
    (ok true)
  )
)

;; Admin function to update voting period
(define-public (set-voting-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set voting-period new-period)
    (ok true)
  )
)

;; Admin function to update quorum threshold
(define-public (set-quorum-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-threshold u100) (err u400))
    (var-set quorum-threshold new-threshold)
    (ok true)
  )
)

;; Admin function to update approval threshold
(define-public (set-approval-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-threshold u100) (err u400))
    (var-set approval-threshold new-threshold)
    (ok true)
  )
)

;; Read-only functions

;; Get proposal details
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

;; Get vote for a specific voter and proposal
(define-read-only (get-vote
    (proposal-id uint)
    (voter principal)
  )
  (map-get? votes {
    proposal-id: proposal-id,
    voter: voter,
  })
)

;; Get voter weight
(define-read-only (get-voter-weight (voter principal))
  (default-to u1 (map-get? voter-weights voter))
)

;; Get current proposal counter
(define-read-only (get-proposal-counter)
  (var-get proposal-counter)
)

;; Get voting parameters
(define-read-only (get-voting-parameters)
  {
    voting-period: (var-get voting-period),
    quorum-threshold: (var-get quorum-threshold),
    approval-threshold: (var-get approval-threshold),
  }
)

;; Check if proposal can be executed
(define-read-only (can-execute-proposal (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal (let (
        (voting-ended (>= stacks-block-height
          (+ (get created-at proposal) (var-get voting-period))
        ))
        (not-executed (not (get executed proposal)))
        (total-weight (get-total-voting-weight))
        (participated-weight (+ (get yes-votes proposal) (get no-votes proposal)))
        (quorum-met (>= (* participated-weight u100)
          (* total-weight (var-get quorum-threshold))
        ))
        (approval-met (>= (* (get yes-votes proposal) u100)
          (* participated-weight (var-get approval-threshold))
        ))
      )
      (and
        voting-ended
        not-executed
        quorum-met
        approval-met
      )
    )
    false
  )
)

;; Helper function to calculate total voting weight
(define-read-only (get-total-voting-weight)
  ;; In a real implementation, this would sum all voter weights
  ;; For simplicity, we return a fixed value
  u1000
)
