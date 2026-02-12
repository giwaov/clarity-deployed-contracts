;; StackSusu Governance v5
;; Circle governance and voting system

(define-constant CONTRACT-OWNER tx-sender)

;; Proposal types
(define-constant PROPOSAL-EXTEND-DEADLINE u1)
(define-constant PROPOSAL-CHANGE-INTERVAL u2)
(define-constant PROPOSAL-PAUSE-CIRCLE u3)
(define-constant PROPOSAL-RESUME-CIRCLE u4)
(define-constant PROPOSAL-REMOVE-MEMBER u5)
(define-constant PROPOSAL-CHANGE-ORDER u6)

;; Proposal status
(define-constant STATUS-ACTIVE u0)
(define-constant STATUS-PASSED u1)
(define-constant STATUS-REJECTED u2)
(define-constant STATUS-EXECUTED u3)
(define-constant STATUS-EXPIRED u4)

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u4000))
(define-constant ERR-NOT-MEMBER (err u4001))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u4002))
(define-constant ERR-ALREADY-VOTED (err u4003))
(define-constant ERR-PROPOSAL-EXPIRED (err u4004))
(define-constant ERR-PROPOSAL-NOT-PASSED (err u4005))
(define-constant ERR-INVALID-PROPOSAL-TYPE (err u4006))
(define-constant ERR-CIRCLE-NOT-FOUND (err u4007))
(define-constant ERR-PAUSED (err u4008))
(define-constant ERR-QUORUM-NOT-MET (err u4009))

;; Governance parameters
(define-constant VOTING-PERIOD-BLOCKS u432)     ;; ~3 days
(define-constant EXECUTION-DELAY-BLOCKS u144)   ;; ~1 day delay after passing
(define-constant QUORUM-PERCENT u50)            ;; 50% of members must vote

;; Proposal counter
(define-data-var proposal-counter uint u0)

;; Proposals
(define-map proposals
  uint
  {
    circle-id: uint,
    proposer: principal,
    proposal-type: uint,
    description: (string-ascii 100),
    value: uint,                      ;; Generic value (new interval, slot to change, etc.)
    target-member: (optional principal),  ;; For member-related proposals
    votes-for: uint,
    votes-against: uint,
    total-voters: uint,
    status: uint,
    created-at: uint,
    expires-at: uint,
    executed-at: uint
  }
)

;; Vote records
(define-map votes
  { proposal-id: uint, voter: principal }
  { vote: bool, voted-at: uint }
)

;; Circle proposal tracking
(define-map circle-proposals
  uint
  (list 20 uint)
)

;; Authorized executors
(define-map authorized-executors principal bool)


;; ============================================
;; Authorization
;; ============================================

(define-public (authorize-executor (executor principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-executors executor true))
  )
)

(define-public (revoke-executor (executor principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-delete authorized-executors executor))
  )
)


;; ============================================
;; Create Proposal
;; ============================================

(define-public (create-proposal 
    (circle-id uint) 
    (proposal-type uint)
    (description (string-ascii 100))
    (value uint)
    (target-member (optional principal)))
  (let
    (
      (proposer tx-sender)
      (proposal-id (+ (var-get proposal-counter) u1))
      (circle-info (unwrap! (contract-call? .stacksusu-core-v5 get-circle-info circle-id) 
                            ERR-CIRCLE-NOT-FOUND))
      (circle (unwrap! circle-info ERR-CIRCLE-NOT-FOUND))
      (is-member (contract-call? .stacksusu-core-v5 is-member circle-id proposer))
      (current-proposals (default-to (list) (map-get? circle-proposals circle-id)))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v5 is-paused)) ERR-PAUSED)
    (asserts! is-member ERR-NOT-MEMBER)
    (asserts! (and (>= proposal-type PROPOSAL-EXTEND-DEADLINE) 
                   (<= proposal-type PROPOSAL-CHANGE-ORDER))
              ERR-INVALID-PROPOSAL-TYPE)
    
    ;; Create proposal
    (map-set proposals proposal-id
      {
        circle-id: circle-id,
        proposer: proposer,
        proposal-type: proposal-type,
        description: description,
        value: value,
        target-member: target-member,
        votes-for: u1,      ;; Proposer auto-votes for
        votes-against: u0,
        total-voters: u1,
        status: STATUS-ACTIVE,
        created-at: block-height,
        expires-at: (+ block-height VOTING-PERIOD-BLOCKS),
        executed-at: u0
      }
    )
    
    ;; Record proposer's vote
    (map-set votes 
      { proposal-id: proposal-id, voter: proposer }
      { vote: true, voted-at: block-height }
    )
    
    ;; Track proposal in circle
    (map-set circle-proposals circle-id
      (unwrap! (as-max-len? (append current-proposals proposal-id) u20) ERR-NOT-AUTHORIZED)
    )
    
    (var-set proposal-counter proposal-id)
    (ok proposal-id)
  )
)


;; ============================================
;; Vote on Proposal
;; ============================================

(define-public (vote (proposal-id uint) (vote-for bool))
  (let
    (
      (voter tx-sender)
      (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
      (circle-id (get circle-id proposal))
      (is-member (contract-call? .stacksusu-core-v5 is-member circle-id voter))
      (existing-vote (map-get? votes { proposal-id: proposal-id, voter: voter }))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v5 is-paused)) ERR-PAUSED)
    (asserts! is-member ERR-NOT-MEMBER)
    (asserts! (is-eq (get status proposal) STATUS-ACTIVE) ERR-PROPOSAL-EXPIRED)
    (asserts! (< block-height (get expires-at proposal)) ERR-PROPOSAL-EXPIRED)
    (asserts! (is-none existing-vote) ERR-ALREADY-VOTED)
    
    ;; Record vote
    (map-set votes 
      { proposal-id: proposal-id, voter: voter }
      { vote: vote-for, voted-at: block-height }
    )
    
    ;; Update proposal counts
    (map-set proposals proposal-id
      (merge proposal {
        votes-for: (if vote-for 
                     (+ (get votes-for proposal) u1) 
                     (get votes-for proposal)),
        votes-against: (if vote-for 
                         (get votes-against proposal) 
                         (+ (get votes-against proposal) u1)),
        total-voters: (+ (get total-voters proposal) u1)
      })
    )
    
    (ok true)
  )
)


;; ============================================
;; Finalize Proposal
;; ============================================

(define-public (finalize-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
      (circle-info (unwrap! (contract-call? .stacksusu-core-v5 get-circle-info (get circle-id proposal))
                            ERR-CIRCLE-NOT-FOUND))
      (circle (unwrap! circle-info ERR-CIRCLE-NOT-FOUND))
      (member-count (get max-members circle))
      (quorum-needed (/ (* member-count QUORUM-PERCENT) u100))
      (total-votes (get total-voters proposal))
      (votes-for (get votes-for proposal))
      (votes-against (get votes-against proposal))
    )
    (asserts! (is-eq (get status proposal) STATUS-ACTIVE) ERR-PROPOSAL-EXPIRED)
    (asserts! (>= block-height (get expires-at proposal)) ERR-NOT-AUTHORIZED)
    
    ;; Check quorum
    (if (< total-votes quorum-needed)
      ;; Quorum not met - expired
      (begin
        (map-set proposals proposal-id (merge proposal { status: STATUS-EXPIRED }))
        (ok STATUS-EXPIRED)
      )
      ;; Quorum met - check result
      (if (> votes-for votes-against)
        ;; Passed
        (begin
          (map-set proposals proposal-id (merge proposal { status: STATUS-PASSED }))
          (ok STATUS-PASSED)
        )
        ;; Rejected
        (begin
          (map-set proposals proposal-id (merge proposal { status: STATUS-REJECTED }))
          (ok STATUS-REJECTED)
        )
      )
    )
  )
)


;; ============================================
;; Execute Proposal
;; ============================================

(define-public (execute-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
      (execution-delay-met (>= block-height (+ (get expires-at proposal) EXECUTION-DELAY-BLOCKS)))
    )
    (asserts! (is-eq (get status proposal) STATUS-PASSED) ERR-PROPOSAL-NOT-PASSED)
    (asserts! execution-delay-met ERR-NOT-AUTHORIZED)
    
    ;; Execute based on proposal type
    ;; Note: Actual execution logic would call other contracts
    ;; For now, we just mark as executed
    (map-set proposals proposal-id 
      (merge proposal { 
        status: STATUS-EXECUTED,
        executed-at: block-height
      })
    )
    
    (ok true)
  )
)


;; ============================================
;; Read-only Functions
;; ============================================

(define-read-only (get-proposal (proposal-id uint))
  (ok (map-get? proposals proposal-id))
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (ok (map-get? votes { proposal-id: proposal-id, voter: voter }))
)

(define-read-only (get-circle-proposals (circle-id uint))
  (ok (default-to (list) (map-get? circle-proposals circle-id)))
)

(define-read-only (get-proposal-count)
  (var-get proposal-counter)
)

(define-read-only (has-voted (proposal-id uint) (voter principal))
  (is-some (map-get? votes { proposal-id: proposal-id, voter: voter }))
)

(define-read-only (is-proposal-active (proposal-id uint))
  (match (map-get? proposals proposal-id)
    p (and (is-eq (get status p) STATUS-ACTIVE) (< block-height (get expires-at p)))
    false
  )
)

(define-read-only (get-voting-power (circle-id uint) (member principal))
  ;; Each member has 1 vote
  (if (contract-call? .stacksusu-core-v5 is-member circle-id member)
    (ok u1)
    (ok u0)
  )
)

(define-read-only (get-quorum-status (proposal-id uint))
  (let
    (
      (proposal-opt (map-get? proposals proposal-id))
    )
    (match proposal-opt
      proposal
        (let
          (
            (circle-id (get circle-id proposal))
            (circle-opt (unwrap-panic (contract-call? .stacksusu-core-v5 get-circle-info circle-id)))
          )
          (match circle-opt
            circle
              (let
                (
                  (member-count (get max-members circle))
                  (quorum-needed (/ (* member-count QUORUM-PERCENT) u100))
                  (total-votes (get total-voters proposal))
                )
                (ok {
                  quorum-needed: quorum-needed,
                  current-votes: total-votes,
                  quorum-met: (>= total-votes quorum-needed),
                  votes-for: (get votes-for proposal),
                  votes-against: (get votes-against proposal)
                })
              )
            (err u4007)
          )
        )
      (err u4002)
    )
  )
)
