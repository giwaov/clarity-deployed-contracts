;; DAO Governance Contract
;; A complete DAO implementation with treasury management, proposals, and voting

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-member (err u101))
(define-constant err-proposal-not-found (err u102))
(define-constant err-already-voted (err u103))
(define-constant err-voting-ended (err u104))
(define-constant err-proposal-not-passed (err u105))
(define-constant err-proposal-already-executed (err u106))
(define-constant err-insufficient-balance (err u107))
(define-constant err-invalid-amount (err u108))
(define-constant err-voting-not-ended (err u109))

;; Voting duration in blocks (approximately 1 week at 10 min/block)
(define-constant voting-duration u1008)

;; Quorum requirement (% of total members that must vote)
(define-constant quorum-percentage u20)

;; Approval threshold (% of votes needed to pass)
(define-constant approval-threshold u51)

;; Data Variables
(define-data-var proposal-count uint u0)
(define-data-var member-count uint u0)

;; Data Maps
(define-map members principal bool)

(define-map proposals
  uint
  {
    proposer: principal,
    title: (string-ascii 256),
    description: (string-ascii 1024),
    recipient: principal,
    amount: uint,
    start-block: uint,
    end-block: uint,
    yes-votes: uint,
    no-votes: uint,
    executed: bool,
    cancelled: bool
  }
)

(define-map votes
  {proposal-id: uint, voter: principal}
  {vote: bool, power: uint}
)

(define-map member-voting-power principal uint)

;; Private Functions

(define-private (is-member (account principal))
  (default-to false (map-get? members account))
)

(define-private (get-voting-power (account principal))
  (default-to u1 (map-get? member-voting-power account))
)

(define-private (has-voted (proposal-id uint) (voter principal))
  (is-some (map-get? votes {proposal-id: proposal-id, voter: voter}))
)

(define-private (calculate-quorum (total-votes uint))
  (/ (* (var-get member-count) quorum-percentage) u100)
)

(define-private (calculate-approval (yes-votes uint) (total-votes uint))
  (if (> total-votes u0)
    (>= (/ (* yes-votes u100) total-votes) approval-threshold)
    false
  )
)

;; Read-Only Functions

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes {proposal-id: proposal-id, voter: voter})
)

(define-read-only (is-dao-member (account principal))
  (is-member account)
)

(define-read-only (get-member-power (account principal))
  (get-voting-power account)
)

(define-read-only (get-treasury-balance)
  (stx-get-balance current-contract)
)

(define-read-only (get-proposal-count)
  (var-get proposal-count)
)

(define-read-only (get-member-count)
  (var-get member-count)
)

(define-read-only (has-proposal-passed (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal
      (let
        (
          (total-votes (+ (get yes-votes proposal) (get no-votes proposal)))
          (quorum-met (>= total-votes (calculate-quorum total-votes)))
          (approved (calculate-approval (get yes-votes proposal) total-votes))
        )
        (and quorum-met approved)
      )
    false
  )
)

(define-read-only (is-voting-active (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal
      (and
        (< stacks-block-height (get end-block proposal))
        (not (get executed proposal))
        (not (get cancelled proposal))
      )
    false
  )
)

;; Public Functions

;; Initialize DAO with founding members
(define-public (initialize-dao (founding-members (list 10 principal)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map add-member founding-members)
    (ok true)
  )
)

;; Add a new member (governance action)
(define-public (add-member (new-member principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set members new-member true)
    (map-set member-voting-power new-member u1)
    (var-set member-count (+ (var-get member-count) u1))
    (print {event: "member-added", member: new-member})
    (ok true)
  )
)

;; Remove a member (governance action)
(define-public (remove-member (member principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-member member) err-not-member)
    (map-delete members member)
    (map-delete member-voting-power member)
    (var-set member-count (- (var-get member-count) u1))
    (print {event: "member-removed", member: member})
    (ok true)
  )
)

;; Create a new proposal
(define-public (create-proposal 
  (title (string-ascii 256))
  (description (string-ascii 1024))
  (recipient principal)
  (amount uint)
)
  (let
    (
      (proposal-id (+ (var-get proposal-count) u1))
      (start-block stacks-block-height)
      (end-block (+ stacks-block-height voting-duration))
    )
    (asserts! (is-member tx-sender) err-not-member)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (<= amount (get-treasury-balance)) err-insufficient-balance)
    
    (map-set proposals proposal-id
      {
        proposer: tx-sender,
        title: title,
        description: description,
        recipient: recipient,
        amount: amount,
        start-block: start-block,
        end-block: end-block,
        yes-votes: u0,
        no-votes: u0,
        executed: false,
        cancelled: false
      }
    )
    
    (var-set proposal-count proposal-id)
    (print {
      event: "proposal-submitted",
      proposal-id: proposal-id,
      proposer: tx-sender,
      title: title,
      amount: amount,
      recipient: recipient
    })
    (ok proposal-id)
  )
)

;; Vote on a proposal
(define-public (vote (proposal-id uint) (support bool))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
      (voter-power (get-voting-power tx-sender))
    )
    (asserts! (is-member tx-sender) err-not-member)
    (asserts! (not (has-voted proposal-id tx-sender)) err-already-voted)
    (asserts! (is-voting-active proposal-id) err-voting-ended)
    
    ;; Record the vote
    (map-set votes
      {proposal-id: proposal-id, voter: tx-sender}
      {vote: support, power: voter-power}
    )
    
    ;; Update vote counts
    (map-set proposals proposal-id
      (merge proposal
        {
          yes-votes: (if support 
            (+ (get yes-votes proposal) voter-power)
            (get yes-votes proposal)
          ),
          no-votes: (if support 
            (get no-votes proposal)
            (+ (get no-votes proposal) voter-power)
          )
        }
      )
    )
    
    (print {
      event: "vote-cast",
      proposal-id: proposal-id,
      voter: tx-sender,
      support: support,
      power: voter-power
    })
    (ok true)
  )
)

;; Execute a passed proposal
(define-public (execute-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
    )
    (asserts! (>= stacks-block-height (get end-block proposal)) err-voting-not-ended)
    (asserts! (not (get executed proposal)) err-proposal-already-executed)
    (asserts! (has-proposal-passed proposal-id) err-proposal-not-passed)
    
    ;; Transfer funds from treasury
    (try! (as-contract? ((with-stx (get amount proposal)))
      (unwrap! (stx-transfer? 
        (get amount proposal)
        tx-sender
        (get recipient proposal)
      ) (err u500))
    ))
    
    ;; Mark as executed
    (map-set proposals proposal-id
      (merge proposal {executed: true})
    )
    
    (print {
      event: "proposal-executed",
      proposal-id: proposal-id,
      recipient: (get recipient proposal),
      amount: (get amount proposal),
      executor: tx-sender
    })
    (ok true)
  )
)

;; Cancel a proposal (only proposer or owner)
(define-public (cancel-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
    )
    (asserts! 
      (or 
        (is-eq tx-sender (get proposer proposal))
        (is-eq tx-sender contract-owner)
      )
      err-owner-only
    )
    (asserts! (not (get executed proposal)) err-proposal-already-executed)
    
    (map-set proposals proposal-id
      (merge proposal {cancelled: true})
    )
    
    (print {
      event: "proposal-cancelled",
      proposal-id: proposal-id,
      cancelled-by: tx-sender
    })
    (ok true)
  )
)

;; Deposit STX to treasury
(define-public (deposit-to-treasury (amount uint))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (try! (stx-transfer? amount tx-sender current-contract))
    (print {
      event: "treasury-deposit",
      from: tx-sender,
      amount: amount
    })
    (ok true)
  )
)

;; Emergency withdrawal (only owner, for safety)
(define-public (emergency-withdraw (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (try! (as-contract? ((with-stx amount))
      (unwrap! (stx-transfer? amount tx-sender recipient) (err u500))
    ))
    (print {
      event: "emergency-withdrawal",
      amount: amount,
      recipient: recipient
    })
    (ok true)
  )
)

;; Update voting power (governance action)
(define-public (update-voting-power (member principal) (new-power uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-member member) err-not-member)
    (map-set member-voting-power member new-power)
    (print {
      event: "voting-power-updated",
      member: member,
      new-power: new-power
    })
    (ok true)
  )
)