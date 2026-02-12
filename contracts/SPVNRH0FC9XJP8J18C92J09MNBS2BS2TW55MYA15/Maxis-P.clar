;; title: Maxis-P
;; version:
;; summary:
;; description:







(define-constant contract-owner tx-sender)

;; Error codes
(define-constant error-unauthorized (err u100))
(define-constant error-proposal-exists (err u101))
(define-constant error-proposal-not-found (err u102))
(define-constant error-proposal-expired (err u103))
(define-constant error-proposal-not-expired (err u104))
(define-constant error-already-voted (err u105))
(define-constant error-insufficient-tokens (err u106))
(define-constant error-not-proposal-creator (err u107))
(define-constant error-proposal-executed (err u108))
(define-constant error-invalid-proposal-duration (err u109))
(define-constant error-invalid-quorum (err u110))
(define-constant error-not-contract-owner (err u111))
(define-constant error-proposal-not-active (err u112))
(define-constant error-proposal-not-passed (err u113))
(define-constant error-invalid-vote-type (err u114))

;; Vote types
(define-constant vote-type-for u1)
(define-constant vote-type-against u2)
(define-constant vote-type-abstain u3)

;; Proposal status
(define-constant status-active u1)
(define-constant status-passed u2)
(define-constant status-rejected u3)
(define-constant status-executed u4)

;; Data structures
(define-map proposals
  { proposal-id: uint }
  {
    creator: principal,
    title: (string-ascii 64),
    description: (string-ascii 512),
    link: (string-ascii 256),
    start-block: uint,
    end-block: uint,
    quorum-threshold: uint,
    vote-for: uint,
    vote-against: uint,
    vote-abstain: uint,
    status: uint,
    executed-at: (optional uint)
  }
)

(define-map votes
  { proposal-id: uint, voter: principal }
  { 
    weight: uint, 
    vote-type: uint,
    time: uint
  }
)

;; Governance token (simulated)
(define-map token-balances principal uint)

;; Total token supply
(define-data-var total-token-supply uint u10000000)

;; Governance parameters
(define-data-var min-proposal-duration uint u144)  ;; Minimum 144 blocks (roughly 1 day)
(define-data-var default-quorum-threshold uint u2000)  ;; 20% of total tokens
(define-data-var proposal-fee uint u100)  ;; Fee to create proposal
(define-data-var next-proposal-id uint u1)

;; Read-only functions

;; Get proposal details
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

;; Get vote details
(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter })
)

;; Check if a proposal exists
(define-read-only (proposal-exists (proposal-id uint))
  (is-some (get-proposal proposal-id))
)

;; Check if a proposal is active
(define-read-only (is-proposal-active (proposal-id uint))
  (match (get-proposal proposal-id)
    proposal (and 
              (is-eq (get status proposal) status-active)
              (< stacks-block-height (get end-block proposal))
            )
    false
  )
)

;; Check if a proposal has ended
(define-read-only (has-proposal-ended (proposal-id uint))
  (match (get-proposal proposal-id)
    proposal (>= stacks-block-height (get end-block proposal))
    false
  )
)

;; Get token balance
(define-read-only (get-token-balance (account principal))
  (default-to u0 (map-get? token-balances account))
)

;; Get total token supply
(define-read-only (get-total-supply)
  (var-get total-token-supply)
)

;; Get proposal results
(define-read-only (get-proposal-results (proposal-id uint))
  (match (get-proposal proposal-id)
    proposal {
      vote-for: (get vote-for proposal),
      vote-against: (get vote-against proposal),
      vote-abstain: (get vote-abstain proposal),
      total-votes: (+ (get vote-for proposal) (get vote-against proposal) (get vote-abstain proposal)),
      quorum-reached: (>= (+ (get vote-for proposal) (get vote-against proposal) (get vote-abstain proposal)) (get quorum-threshold proposal)),
      passed: (and 
                (>= (+ (get vote-for proposal) (get vote-against proposal) (get vote-abstain proposal)) (get quorum-threshold proposal))
                (> (get vote-for proposal) (get vote-against proposal))
              )
    }
    { vote-for: u0, vote-against: u0, vote-abstain: u0, total-votes: u0, quorum-reached: false, passed: false }
  )
)

;; Get current proposal ID
(define-read-only (get-current-proposal-id)
  (var-get next-proposal-id)
)

;; Helper functions

;; Check if a vote type is valid
(define-private (is-valid-vote-type (vote-type uint))
  (or (is-eq vote-type vote-type-for)
      (or (is-eq vote-type vote-type-against)
          (is-eq vote-type vote-type-abstain)))
)






;; Calculate proposal status after voting period
(define-private (calculate-proposal-status (proposal-id uint))
  (match (get-proposal proposal-id)
    proposal 
      (let ((total-votes (+ (get vote-for proposal) (get vote-against proposal) (get vote-abstain proposal))))
        (if (>= total-votes (get quorum-threshold proposal))
          (if (> (get vote-for proposal) (get vote-against proposal))
            status-passed
            status-rejected)
          status-rejected))
    status-rejected)
)

;; Public functions

;; Create a new proposal
(define-public (create-proposal 
                (title (string-ascii 64))
                (description (string-ascii 512))
                (link (string-ascii 256))
                (duration uint)
                (quorum-threshold uint))
  (let ((proposal-id (var-get next-proposal-id))
        (start-block stacks-block-height)
        (end-block (+ stacks-block-height duration))
        (creator-balance (get-token-balance tx-sender)))
    (begin
      ;; Validate inputs
      (asserts! (>= duration (var-get min-proposal-duration)) error-invalid-proposal-duration)
      (asserts! (>= quorum-threshold (var-get default-quorum-threshold)) error-invalid-quorum)
      (asserts! (>= creator-balance (var-get proposal-fee)) error-insufficient-tokens)

      ;; Subtract proposal fee from creator
      (map-set token-balances tx-sender (- creator-balance (var-get proposal-fee)))

      ;; Create proposal
      (map-set proposals
        { proposal-id: proposal-id }
        {
          creator: tx-sender,
          title: title,
          description: description,
          link: link,
          start-block: start-block,
          end-block: end-block,
          quorum-threshold: quorum-threshold,
          vote-for: u0,
          vote-against: u0,
          vote-abstain: u0,
          status: status-active,
          executed-at: none
        }
      )

      ;; Increment proposal ID
      (var-set next-proposal-id (+ proposal-id u1))

      (ok proposal-id)
    )
  )
)

;; Execute a passed proposal
(define-public (execute-proposal (proposal-id uint))
  (let ((proposal (unwrap! (get-proposal proposal-id) error-proposal-not-found)))
    (begin
      ;; Check proposal is passed
      (asserts! (is-eq (get status proposal) status-passed) error-proposal-not-passed)

      ;; Check proposal not already executed
      (asserts! (is-none (get executed-at proposal)) error-proposal-executed)

      ;; Update proposal as executed
      (map-set proposals
        { proposal-id: proposal-id }
        (merge proposal { 
          status: status-executed,
          executed-at: (some stacks-block-height)
        })
      )

      ;; Note: In a real implementation, this would trigger execution logic
      ;; for the specific proposal type, such as treasury transfers, parameter
      ;; updates, etc.

      (ok true)
    )
  )
)

;; Administrative functions

;; Mint governance tokens (for testing/simulation purposes)
(define-public (mint-tokens (recipient principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) error-not-contract-owner)

    (let ((current-balance (get-token-balance recipient))
          (new-balance (+ current-balance amount)))

      ;; Update recipient balance
      (map-set token-balances recipient new-balance)

      ;; Update total supply
      (var-set total-token-supply (+ (var-get total-token-supply) amount))

      (ok new-balance)
    )
  )
)

;; Update proposal fee
(define-public (update-proposal-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) error-not-contract-owner)
    (ok (var-set proposal-fee new-fee))
  )
)

;; Update minimum proposal duration
(define-public (update-min-proposal-duration (new-duration uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) error-not-contract-owner)
    (ok (var-set min-proposal-duration new-duration))
  )
)

;; Update default quorum threshold
(define-public (update-default-quorum-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) error-not-contract-owner)
    (ok (var-set default-quorum-threshold new-threshold))
  )
)







