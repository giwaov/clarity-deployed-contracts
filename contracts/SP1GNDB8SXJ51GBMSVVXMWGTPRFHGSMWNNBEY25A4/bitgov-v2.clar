
;; bitgov.clar
;; 
;; ============================================
;; title: BitGov
;; summary: A comprehensive DAO governance suite with proposal management, voting, and treasury.
;; ============================================

;; --- Constants & Error Codes ---

(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_EXISTS (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_PROPOSAL_EXPIRED (err u103))
(define-constant ERR_PROPOSAL_NOT_ACTIVE (err u104))
(define-constant ERR_ALREADY_VOTED (err u105))
(define-constant ERR_INSUFFICIENT_FUNDS (err u106))
(define-constant ERR_INVALID_PARAMETER (err u107))
(define-constant ERR_EXECUTION_DELAY_NOT_MET (err u108))
(define-constant ERR_NOT_MEMBER (err u109))
(define-constant ERR_INSUFFICIENT_REPUTATION (err u110))

;; Governance Parameters
(define-constant VOTING_PERIOD u144) ;; ~1 day in blocks (assuming 10 min blocks)
(define-constant EXECUTION_DELAY u144) ;; ~1 day
(define-constant MIN_REPUTATION_TO_PROPOSE u10) ;; Minimum reputation needed to create proposals
(define-constant DEPLOYER_PRINCIPAL tx-sender) ;; Note: this captures runtime sender, usually deployment

;; --- Data Variables ---

(define-data-var proposal-count uint u0)
(define-data-var general-counter uint u0)

;; --- Data Maps ---

;; Proposals
;; Enhanced to include execution details for treasury and membership
(define-map proposals uint {
  proposer: principal,
  title: (string-ascii 50),
  description: (string-utf8 500),
  start-block: uint,
  end-block: uint,
  votes-for: uint,
  votes-against: uint,
  status: (string-ascii 20), ;; "active", "passed", "failed", "executed"
  executed: bool,
  ;; New fields for execution
  transfer-amount: uint,
  transfer-to: (optional principal),
  add-member: (optional principal) ;; If set, this proposal is to add a new member
})

;; Votes: proposal-id -> voter -> { outcome, amount }
(define-map votes { proposal-id: uint, voter: principal } {
  outcome: bool, ;; true = for, false = against
  amount: uint   ;; Reputation weight used
})

;; Members
(define-map members principal {
  reputation: uint,
  joined-at: uint
})

;; --- Public Functions (Governance) ---

;; 1. Create Proposal
;; Updated to support treasury transfers and membership additions
(define-public (create-proposal (title (string-ascii 50)) 
                                (description (string-utf8 500))
                                (transfer-amount uint)
                                (transfer-to (optional principal))
                                (add-member (optional principal)))
  (let
    (
      (current-count (var-get proposal-count))
      (start-height burn-block-height)
      (end-height (+ start-height VOTING_PERIOD))
      (proposer-info (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
    )
    ;; Check proposer reputation (unless it's the very first proposal bootstrapping)
    (asserts! (or (is-eq current-count u0) (>= (get reputation proposer-info) MIN_REPUTATION_TO_PROPOSE)) ERR_INSUFFICIENT_REPUTATION)

    (let
      (
        (new-proposal {
          proposer: tx-sender,
          title: title,
          description: description,
          start-block: start-height,
          end-block: end-height,
          votes-for: u0,
          votes-against: u0,
          status: "active",
          executed: false,
          transfer-amount: transfer-amount,
          transfer-to: transfer-to,
          add-member: add-member
        })
      )
      (map-set proposals current-count new-proposal)
      (var-set proposal-count (+ current-count u1))
      
      ;; EVENT: Proposal Created
      (print {
        event: "proposal-created",
        proposal-id: current-count,
        proposer: tx-sender,
        title: title,
        transfer-amount: transfer-amount
      })
      (ok current-count)
    )
  )
)

;; 2. Vote
;; Updated to use reputation as voting weight
(define-public (vote (proposal-id uint) (vote-for bool))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_NOT_FOUND))
      (voter-info (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
      (voter-participation (map-get? votes { proposal-id: proposal-id, voter: tx-sender }))
    )
    ;; Checks
    (asserts! (is-eq (get status proposal) "active") ERR_PROPOSAL_NOT_ACTIVE)
    (asserts! (<= burn-block-height (get end-block proposal)) ERR_PROPOSAL_EXPIRED)
    (asserts! (is-none voter-participation) ERR_ALREADY_VOTED)
    
    (let
      (
        (weight (get reputation voter-info))
        (current-votes-for (get votes-for proposal))
        (current-votes-against (get votes-against proposal))
        (new-votes-for (if vote-for (+ current-votes-for weight) current-votes-for))
        (new-votes-against (if (not vote-for) (+ current-votes-against weight) current-votes-against))
      )
      ;; Update Proposal
      (map-set proposals proposal-id (merge proposal {
        votes-for: new-votes-for,
        votes-against: new-votes-against
      }))
      
      ;; Record Vote
      (map-set votes { proposal-id: proposal-id, voter: tx-sender } {
        outcome: vote-for,
        amount: weight
      })
      
      ;; EVENT: Vote Cast
      (print {
        event: "vote-cast",
        proposal-id: proposal-id,
        voter: tx-sender,
        outcome: vote-for,
        weight: weight
      })
      
      (ok true)
    )
  )
)

;; 3. Execute Proposal
;; Updated to handle treasury transfers and membership additions
(define-public (execute-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_NOT_FOUND))
    )
    (asserts! (> burn-block-height (get end-block proposal)) ERR_EXECUTION_DELAY_NOT_MET)
    (asserts! (is-eq (get status proposal) "active") ERR_PROPOSAL_NOT_ACTIVE)
    
    (let
      (
        (passed (> (get votes-for proposal) (get votes-against proposal)))
        (new-status (if passed "passed" "failed"))
      )
      
      ;; Execution Logic
      (if passed
        (begin
           ;; Treasury Transfer
           (if (> (get transfer-amount proposal) u0)
              (match (get transfer-to proposal)
                recipient (match (transfer-from-vault (get transfer-amount proposal) recipient)
                           success true
                           error false)
                false) 
              false
           )
           
           ;; Add Member
           (match (get add-member proposal)
              new-member (map-set members new-member { reputation: u10, joined-at: burn-block-height })
              false
           )
        )
        false
      )

      (map-set proposals proposal-id (merge proposal {
        status: new-status,
        executed: passed
      }))
      
      ;; EVENT: Proposal Concluded
      (print {
        event: "proposal-concluded",
        proposal-id: proposal-id,
        status: new-status,
        votes-for: (get votes-for proposal),
        votes-against: (get votes-against proposal),
        executed: passed
      })
      
      (ok passed)
    )
  )
)

;; --- Treasury Functions ---

(define-public (deposit (amount uint))
  (stx-transfer? amount tx-sender (as-contract tx-sender))
)

;; --- Membership Functions ---

;; Bootstrap function (only useful for initialization/testing in this simplified version)
;; In production, initial members would be set in contract-init or via DAO bootstrapping event
(define-public (bootstrap-member (new-member principal) (reputation uint))
  (let
     ((existing-count (var-get general-counter))) ;; reusing counter as crude "initialized" check or just allow anyone
      ;; For safety, let's only allow this if map is empty-ish or restrict to deployer?
      ;; For this "template", we'll restrict to deployer to seed the DAO
      (begin
        (asserts! (is-eq tx-sender DEPLOYER_PRINCIPAL) ERR_UNAUTHORIZED)
        (map-set members new-member { reputation: reputation, joined-at: burn-block-height })
        (ok true)
      )
  )
)
;; Since we don't have contract-init param for deployer, let's assume tx-sender is deployer at init? 
;; Or just hardcode deployer.
;; Actually, better to just allow the first member to be self-registered or hardcode in define-map?
;; define-map is empty.
;; Let's add a public initialization function that can only be called once to adding the caller as the first member.

(define-data-var initialized bool false)

(define-public (initialize-dao)
  (begin
    (asserts! (not (var-get initialized)) ERR_ALREADY_EXISTS)
    (var-set initialized true)
    (map-set members tx-sender { reputation: u100, joined-at: burn-block-height })
    (ok true)
  )
)


;; --- Utility Functions (Counter Logic) ---

(define-public (increment)
  (let ((new-val (+ (var-get general-counter) u1)))
    (begin
      (var-set general-counter new-val)
      ;; EVENT: Counter Incremented
      (print {
        event: "counter-increment",
        caller: tx-sender,
        new-value: new-val
      })
      (ok new-val)
    )
  )
)

(define-public (decrement)
  (let ((current-val (var-get general-counter)))
    (begin
      (asserts! (> current-val u0) (err u109)) ;; Underflow protection
      (let ((new-val (- current-val u1)))
        (var-set general-counter new-val)
        ;; EVENT: Counter Decremented
        (print {
          event: "counter-decrement",
          caller: tx-sender,
          new-value: new-val
        })
        (ok new-val)
      )
    )
  )
)

;; --- Read-Only Functions ---

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-signature-count) ;; Kept name for compatibility/checking, but maps to proposal-count
  (var-get proposal-count)
)

(define-read-only (get-general-counter)
  (var-get general-counter)
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-member-info (member principal))
    (map-get? members member)
)

(define-read-only (get-treasury-balance)
    (stx-get-balance (as-contract tx-sender))
)

;; Private helper to transfer funds
(define-private (transfer-from-vault (amount uint) (recipient principal))
  (as-contract (stx-transfer? amount tx-sender recipient))
)

;; Private helper to define constants we might need
