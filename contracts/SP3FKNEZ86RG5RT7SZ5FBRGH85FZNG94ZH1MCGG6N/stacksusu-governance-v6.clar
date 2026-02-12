;; StackSusu Governance v6
;; Enhanced governance with quadratic voting, delegation, and timelock

(define-constant CONTRACT-OWNER tx-sender)

;; Proposal types
(define-constant PROPOSAL-EXTEND-DEADLINE u1)
(define-constant PROPOSAL-CHANGE-INTERVAL u2)
(define-constant PROPOSAL-PAUSE-CIRCLE u3)
(define-constant PROPOSAL-RESUME-CIRCLE u4)
(define-constant PROPOSAL-REMOVE-MEMBER u5)
(define-constant PROPOSAL-CHANGE-ORDER u6)
(define-constant PROPOSAL-UPDATE-FEE u7)        ;; NEW: Fee changes
(define-constant PROPOSAL-EMERGENCY-ACTION u8)  ;; NEW: Emergency proposals
(define-constant PROPOSAL-UPGRADE-CONTRACT u9)  ;; NEW: Contract upgrades

;; Proposal status
(define-constant STATUS-ACTIVE u0)
(define-constant STATUS-PASSED u1)
(define-constant STATUS-REJECTED u2)
(define-constant STATUS-EXECUTED u3)
(define-constant STATUS-EXPIRED u4)
(define-constant STATUS-QUEUED u5)      ;; NEW: Waiting in timelock
(define-constant STATUS-CANCELLED u6)   ;; NEW: Cancelled before execution

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
(define-constant ERR-TIMELOCK-NOT-EXPIRED (err u4010))
(define-constant ERR-ALREADY-DELEGATED (err u4011))
(define-constant ERR-NOT-DELEGATED (err u4012))
(define-constant ERR-SELF-DELEGATION (err u4013))
(define-constant ERR-DELEGATION-LOOP (err u4014))

;; Governance parameters
(define-constant VOTING-PERIOD-BLOCKS u432)     ;; ~3 days
(define-constant EXECUTION-DELAY-BLOCKS u144)   ;; ~1 day delay after passing
(define-constant QUORUM-PERCENT u50)            ;; 50% of members must vote
(define-constant TIMELOCK-BLOCKS u288)          ;; ~2 days timelock for execution
(define-constant EMERGENCY-QUORUM-PERCENT u75)  ;; 75% for emergency proposals

;; Proposal counter
(define-data-var proposal-counter uint u0)

;; Proposals
(define-map proposals
  uint
  {
    circle-id: uint,
    proposer: principal,
    proposal-type: uint,
    title: (string-ascii 100),
    description: (string-ascii 500),
    value: uint,
    target-member: (optional principal),
    votes-for: uint,
    votes-against: uint,
    total-voters: uint,
    total-voting-power: uint,
    status: uint,
    created-at: uint,
    expires-at: uint,
    queued-at: uint,
    executed-at: uint,
    use-quadratic: bool
  }
)

;; Vote records with weight
(define-map votes
  { proposal-id: uint, voter: principal }
  { vote: bool, voted-at: uint, weight: uint, delegated-from: (optional principal) }
)

;; Voting power (based on reputation and stake)
(define-map voting-power
  { circle-id: uint, member: principal }
  uint
)

;; Vote delegation
(define-map vote-delegations
  { circle-id: uint, delegator: principal }
  { delegate: principal, delegated-at: uint }
)

;; Delegated power tracking
(define-map delegated-power
  { circle-id: uint, delegate: principal }
  { total-power: uint, delegator-count: uint }
)

;; Circle proposal tracking
(define-map circle-proposals
  uint
  (list 50 uint)
)

;; Execution queue (timelock)
(define-map execution-queue
  uint
  { execute-after: uint, execute-before: uint }
)

;; Authorized executors
(define-map authorized-executors principal bool)

;; Member status for governance (simplified check)
(define-map governance-members
  { circle-id: uint, member: principal }
  bool
)


;; ============================================
;; Integer Square Root (Non-recursive)
;; ============================================

;; Newton's method with fixed iterations (no recursion)
(define-private (sqrt-int (n uint))
  (if (<= n u1)
    n
    (let
      (
        (x0 (/ n u2))
        (x1 (/ (+ x0 (/ n x0)) u2))
        (x2 (/ (+ x1 (/ n x1)) u2))
        (x3 (/ (+ x2 (/ n x2)) u2))
        (x4 (/ (+ x3 (/ n x3)) u2))
      )
      ;; After 4-5 iterations, we have good precision for typical voting power values
      x4
    )
  )
)


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

(define-public (register-governance-member (circle-id uint) (member principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set governance-members { circle-id: circle-id, member: member } true))
  )
)

(define-read-only (is-governance-member (circle-id uint) (member principal))
  (default-to false (map-get? governance-members { circle-id: circle-id, member: member }))
)


;; ============================================
;; Voting Power Management
;; ============================================

(define-public (set-voting-power (circle-id uint) (member principal) (power uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set voting-power { circle-id: circle-id, member: member } power)
    (ok power)
  )
)

(define-read-only (get-voting-power (circle-id uint) (member principal))
  (ok (default-to u100 (map-get? voting-power { circle-id: circle-id, member: member })))
)

(define-read-only (get-effective-voting-power (circle-id uint) (member principal))
  (let
    (
      (own-power (default-to u100 (map-get? voting-power { circle-id: circle-id, member: member })))
      (delegated (default-to { total-power: u0, delegator-count: u0 }
                   (map-get? delegated-power { circle-id: circle-id, delegate: member })))
    )
    (+ own-power (get total-power delegated))
  )
)


;; ============================================
;; Vote Delegation (NEW in v6)
;; ============================================

;; Check delegation at specific level (non-recursive)
(define-private (get-delegate-at-level (circle-id uint) (start principal) (level uint))
  (let
    (
      (l1 (map-get? vote-delegations { circle-id: circle-id, delegator: start }))
    )
    (if (is-eq level u1)
      (match l1 d (some (get delegate d)) none)
      (if (is-eq level u2)
        (match l1 
          d1 
            (match (map-get? vote-delegations { circle-id: circle-id, delegator: (get delegate d1) })
              d2 (some (get delegate d2))
              none)
          none)
        (if (is-eq level u3)
          (match l1 
            d1 
              (match (map-get? vote-delegations { circle-id: circle-id, delegator: (get delegate d1) })
                d2 
                  (match (map-get? vote-delegations { circle-id: circle-id, delegator: (get delegate d2) })
                    d3 (some (get delegate d3))
                    none)
                none)
            none)
          none
        )
      )
    )
  )
)

;; Check for delegation loop (non-recursive, checks 3 levels)
(define-private (has-delegation-loop-check (circle-id uint) (delegate principal) (target principal))
  (let
    (
      (l1 (get-delegate-at-level circle-id delegate u1))
      (l2 (get-delegate-at-level circle-id delegate u2))
      (l3 (get-delegate-at-level circle-id delegate u3))
    )
    (or
      (is-eq (some target) l1)
      (is-eq (some target) l2)
      (is-eq (some target) l3)
    )
  )
)

(define-public (delegate-votes (circle-id uint) (delegate principal))
  (let
    (
      (delegator tx-sender)
      (delegator-power (default-to u100 (map-get? voting-power { circle-id: circle-id, member: delegator })))
      (existing-delegation (map-get? vote-delegations { circle-id: circle-id, delegator: delegator }))
      (delegate-delegated (map-get? delegated-power { circle-id: circle-id, delegate: delegate }))
    )
    (asserts! (is-governance-member circle-id delegator) ERR-NOT-MEMBER)
    (asserts! (is-governance-member circle-id delegate) ERR-NOT-MEMBER)
    (asserts! (not (is-eq delegator delegate)) ERR-SELF-DELEGATION)
    (asserts! (is-none existing-delegation) ERR-ALREADY-DELEGATED)
    
    ;; Check for delegation loops
    (asserts! (not (has-delegation-loop-check circle-id delegate delegator)) ERR-DELEGATION-LOOP)
    
    ;; Record delegation
    (map-set vote-delegations { circle-id: circle-id, delegator: delegator }
      { delegate: delegate, delegated-at: block-height })
    
    ;; Update delegate's power
    (map-set delegated-power { circle-id: circle-id, delegate: delegate }
      {
        total-power: (+ (default-to u0 (match delegate-delegated d (some (get total-power d)) none)) delegator-power),
        delegator-count: (+ (default-to u0 (match delegate-delegated d (some (get delegator-count d)) none)) u1)
      })
    
    (ok true)
  )
)

(define-public (revoke-delegation (circle-id uint))
  (let
    (
      (delegator tx-sender)
      (delegation (unwrap! (map-get? vote-delegations { circle-id: circle-id, delegator: delegator }) 
                           ERR-NOT-DELEGATED))
      (delegate (get delegate delegation))
      (delegator-power (default-to u100 (map-get? voting-power { circle-id: circle-id, member: delegator })))
      (delegate-data (unwrap! (map-get? delegated-power { circle-id: circle-id, delegate: delegate })
                              ERR-NOT-DELEGATED))
    )
    (map-delete vote-delegations { circle-id: circle-id, delegator: delegator })
    
    ;; Update delegate's power
    (map-set delegated-power { circle-id: circle-id, delegate: delegate }
      {
        total-power: (- (get total-power delegate-data) delegator-power),
        delegator-count: (- (get delegator-count delegate-data) u1)
      })
    
    (ok true)
  )
)


;; ============================================
;; Create Proposal
;; ============================================

(define-public (create-proposal 
    (circle-id uint) 
    (proposal-type uint)
    (title (string-ascii 100))
    (description (string-ascii 500))
    (value uint)
    (target-member (optional principal))
    (use-quadratic bool))
  (let
    (
      (proposer tx-sender)
      (proposal-id (+ (var-get proposal-counter) u1))
      (proposer-power (get-effective-voting-power circle-id proposer))
      (current-proposals (default-to (list) (map-get? circle-proposals circle-id)))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v6 is-paused)) ERR-PAUSED)
    (asserts! (is-governance-member circle-id proposer) ERR-NOT-MEMBER)
    (asserts! (and (>= proposal-type PROPOSAL-EXTEND-DEADLINE) 
                   (<= proposal-type PROPOSAL-UPGRADE-CONTRACT))
              ERR-INVALID-PROPOSAL-TYPE)
    
    ;; Create proposal
    (map-set proposals proposal-id
      {
        circle-id: circle-id,
        proposer: proposer,
        proposal-type: proposal-type,
        title: title,
        description: description,
        value: value,
        target-member: target-member,
        votes-for: proposer-power,
        votes-against: u0,
        total-voters: u1,
        total-voting-power: proposer-power,
        status: STATUS-ACTIVE,
        created-at: block-height,
        expires-at: (+ block-height VOTING-PERIOD-BLOCKS),
        queued-at: u0,
        executed-at: u0,
        use-quadratic: use-quadratic
      }
    )
    
    ;; Record proposer's vote
    (map-set votes 
      { proposal-id: proposal-id, voter: proposer }
      { vote: true, voted-at: block-height, weight: proposer-power, delegated-from: none }
    )
    
    ;; Track proposal in circle
    (map-set circle-proposals circle-id
      (unwrap! (as-max-len? (append current-proposals proposal-id) u50) ERR-NOT-AUTHORIZED)
    )
    
    (var-set proposal-counter proposal-id)
    (ok proposal-id)
  )
)


;; ============================================
;; Voting
;; ============================================

(define-public (vote (proposal-id uint) (support bool))
  (let
    (
      (voter tx-sender)
      (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
      (circle-id (get circle-id proposal))
      (existing-vote (map-get? votes { proposal-id: proposal-id, voter: voter }))
      (raw-power (get-effective-voting-power circle-id voter))
      (vote-weight (if (get use-quadratic proposal)
                     (sqrt-int raw-power)
                     raw-power))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v6 is-paused)) ERR-PAUSED)
    (asserts! (is-governance-member circle-id voter) ERR-NOT-MEMBER)
    (asserts! (is-none existing-vote) ERR-ALREADY-VOTED)
    (asserts! (is-eq (get status proposal) STATUS-ACTIVE) ERR-PROPOSAL-EXPIRED)
    (asserts! (< block-height (get expires-at proposal)) ERR-PROPOSAL-EXPIRED)
    
    ;; Record vote
    (map-set votes 
      { proposal-id: proposal-id, voter: voter }
      { vote: support, voted-at: block-height, weight: vote-weight, delegated-from: none }
    )
    
    ;; Update proposal
    (map-set proposals proposal-id
      (merge proposal {
        votes-for: (if support (+ (get votes-for proposal) vote-weight) (get votes-for proposal)),
        votes-against: (if support (get votes-against proposal) (+ (get votes-against proposal) vote-weight)),
        total-voters: (+ (get total-voters proposal) u1),
        total-voting-power: (+ (get total-voting-power proposal) vote-weight)
      })
    )
    
    (ok vote-weight)
  )
)


;; ============================================
;; Proposal Finalization
;; ============================================

(define-public (finalize-proposal (proposal-id uint) (member-count uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
      (quorum-required (if (is-eq (get proposal-type proposal) PROPOSAL-EMERGENCY-ACTION)
                         (/ (* member-count EMERGENCY-QUORUM-PERCENT) u100)
                         (/ (* member-count QUORUM-PERCENT) u100)))
      (votes-for (get votes-for proposal))
      (votes-against (get votes-against proposal))
      (total-voters (get total-voters proposal))
    )
    (asserts! (is-eq (get status proposal) STATUS-ACTIVE) ERR-PROPOSAL-NOT-FOUND)
    (asserts! (>= block-height (get expires-at proposal)) ERR-NOT-AUTHORIZED)
    
    (if (< total-voters quorum-required)
      ;; Quorum not met - reject
      (begin
        (map-set proposals proposal-id (merge proposal { status: STATUS-REJECTED }))
        (ok STATUS-REJECTED)
      )
      ;; Check if passed
      (if (> votes-for votes-against)
        ;; Passed - add to timelock queue
        (begin
          (map-set proposals proposal-id (merge proposal { 
            status: STATUS-QUEUED,
            queued-at: block-height
          }))
          (map-set execution-queue proposal-id {
            execute-after: (+ block-height TIMELOCK-BLOCKS),
            execute-before: (+ block-height TIMELOCK-BLOCKS VOTING-PERIOD-BLOCKS)
          })
          (ok STATUS-QUEUED)
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
;; Execution
;; ============================================

(define-public (execute-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
      (queue-info (unwrap! (map-get? execution-queue proposal-id) ERR-PROPOSAL-NOT-FOUND))
    )
    (asserts! (is-eq (get status proposal) STATUS-QUEUED) ERR-PROPOSAL-NOT-PASSED)
    (asserts! (>= block-height (get execute-after queue-info)) ERR-TIMELOCK-NOT-EXPIRED)
    (asserts! (< block-height (get execute-before queue-info)) ERR-PROPOSAL-EXPIRED)
    
    ;; Execute based on proposal type
    ;; (Actual execution logic would call other contracts)
    
    (map-set proposals proposal-id (merge proposal {
      status: STATUS-EXECUTED,
      executed-at: block-height
    }))
    
    (map-delete execution-queue proposal-id)
    
    (ok true)
  )
)

(define-public (cancel-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
    )
    (asserts! (or (is-eq tx-sender (get proposer proposal))
                  (is-eq tx-sender CONTRACT-OWNER))
              ERR-NOT-AUTHORIZED)
    (asserts! (or (is-eq (get status proposal) STATUS-ACTIVE)
                  (is-eq (get status proposal) STATUS-QUEUED))
              ERR-NOT-AUTHORIZED)
    
    (map-set proposals proposal-id (merge proposal { status: STATUS-CANCELLED }))
    (map-delete execution-queue proposal-id)
    
    (ok true)
  )
)


;; ============================================
;; Read-Only Functions
;; ============================================

(define-read-only (get-proposal (proposal-id uint))
  (ok (map-get? proposals proposal-id))
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (has-voted (proposal-id uint) (voter principal))
  (is-some (map-get? votes { proposal-id: proposal-id, voter: voter }))
)

(define-read-only (get-circle-proposals (circle-id uint))
  (default-to (list) (map-get? circle-proposals circle-id))
)

(define-read-only (get-proposal-count)
  (var-get proposal-counter)
)

(define-read-only (get-delegation (circle-id uint) (delegator principal))
  (map-get? vote-delegations { circle-id: circle-id, delegator: delegator })
)

(define-read-only (get-delegated-power-info (circle-id uint) (delegate principal))
  (map-get? delegated-power { circle-id: circle-id, delegate: delegate })
)

(define-read-only (get-execution-info (proposal-id uint))
  (map-get? execution-queue proposal-id)
)

(define-read-only (is-proposal-executable (proposal-id uint))
  (match (map-get? execution-queue proposal-id)
    queue-info
      (and 
        (>= block-height (get execute-after queue-info))
        (< block-height (get execute-before queue-info))
      )
    false
  )
)
