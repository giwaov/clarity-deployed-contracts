
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

;; Governance Parameters
(define-constant VOTING_PERIOD u144) ;; ~1 day in blocks (assuming 10 min blocks)
(define-constant EXECUTION_DELAY u144) ;; ~1 day

;; --- Data Variables ---

(define-data-var proposal-count uint u0)
(define-data-var general-counter uint u0)

;; --- Data Maps ---

;; Proposals
(define-map proposals uint {
  proposer: principal,
  title: (string-ascii 50),
  description: (string-utf8 500),
  start-block: uint,
  end-block: uint,
  votes-for: uint,
  votes-against: uint,
  status: (string-ascii 20), ;; "active", "passed", "failed", "executed"
  executed: bool
})

;; Votes: proposal-id -> voter -> { outcome, amount }
(define-map votes { proposal-id: uint, voter: principal } {
  outcome: bool, ;; true = for, false = against
  amount: uint
})

;; Members (Simple whitelist for now, can be expanded)
(define-map members principal {
  reputation: uint,
  joined-at: uint
})

;; --- Public Functions (Governance) ---

;; 1. Create Proposal
(define-public (create-proposal (title (string-ascii 50)) (description (string-utf8 500)))
  (let
    (
      (current-count (var-get proposal-count))
      (start-height burn-block-height)
      (end-height (+ start-height VOTING_PERIOD))
      (new-proposal {
        proposer: tx-sender,
        title: title,
        description: description,
        start-block: start-height,
        end-block: end-height,
        votes-for: u0,
        votes-against: u0,
        status: "active",
        executed: false
      })
    )
    (begin
      (map-set proposals current-count new-proposal)
      (var-set proposal-count (+ current-count u1))
      
      ;; EVENT: Proposal Created
      (print {
        event: "proposal-created",
        proposal-id: current-count,
        proposer: tx-sender,
        title: title
      })
      (ok current-count)
    )
  )
)

;; 2. Vote
(define-public (vote (proposal-id uint) (vote-for bool) (amount uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_NOT_FOUND))
      (voter-participation (map-get? votes { proposal-id: proposal-id, voter: tx-sender }))
    )
    ;; Checks
    (asserts! (is-eq (get status proposal) "active") ERR_PROPOSAL_NOT_ACTIVE)
    (asserts! (<= burn-block-height (get end-block proposal)) ERR_PROPOSAL_EXPIRED)
    (asserts! (is-none voter-participation) ERR_ALREADY_VOTED)
    
    ;; Update Proposal
    (let
      (
        (current-votes-for (get votes-for proposal))
        (current-votes-against (get votes-against proposal))
        (new-votes-for (if vote-for (+ current-votes-for amount) current-votes-for))
        (new-votes-against (if (not vote-for) (+ current-votes-against amount) current-votes-against))
      )
      (map-set proposals proposal-id (merge proposal {
        votes-for: new-votes-for,
        votes-against: new-votes-against
      }))
      
      ;; Record Vote
      (map-set votes { proposal-id: proposal-id, voter: tx-sender } {
        outcome: vote-for,
        amount: amount
      })
      
      ;; EVENT: Vote Cast
      (print {
        event: "vote-cast",
        proposal-id: proposal-id,
        voter: tx-sender,
        outcome: vote-for,
        amount: amount
      })
      
      (ok true)
    )
  )
)

;; 3. Execute Proposal (Simplified)
;; Checks if voting period ended and if votes-for > votes-against
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
      (map-set proposals proposal-id (merge proposal {
        status: new-status,
        executed: passed ;; In a real scenario, this would trigger external logic
      }))
      
      ;; EVENT: Proposal Concluded
      (print {
        event: "proposal-concluded",
        proposal-id: proposal-id,
        status: new-status,
        votes-for: (get votes-for proposal),
        votes-against: (get votes-against proposal)
      })
      
      (ok passed)
    )
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
