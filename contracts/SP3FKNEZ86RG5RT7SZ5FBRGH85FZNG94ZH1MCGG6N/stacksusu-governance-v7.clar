;; StackSusu Governance v7
;; Simplified proposal and voting system

(define-constant CONTRACT-OWNER tx-sender)

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u7000))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u7001))
(define-constant ERR-ALREADY-VOTED (err u7002))
(define-constant ERR-VOTING-CLOSED (err u7003))
(define-constant ERR-VOTING-OPEN (err u7004))
(define-constant ERR-THRESHOLD-NOT-MET (err u7005))

;; Proposal status
(define-constant STATUS-ACTIVE u0)
(define-constant STATUS-PASSED u1)
(define-constant STATUS-FAILED u2)
(define-constant STATUS-EXECUTED u3)

;; Configuration
(define-constant VOTING-PERIOD u1008) ;; ~7 days
(define-constant QUORUM-THRESHOLD u10) ;; Minimum 10 votes
(define-constant PASS-THRESHOLD u51)   ;; 51% to pass

;; State
(define-data-var proposal-counter uint u0)

;; Proposals
(define-map proposals
  uint  ;; proposal-id
  {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    votes-for: uint,
    votes-against: uint,
    status: uint,
    created-at: uint,
    ends-at: uint
  }
)

;; Votes
(define-map votes
  { proposal-id: uint, voter: principal }
  bool  ;; true = for, false = against
)


;; ============================================
;; Proposal Functions
;; ============================================

(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)))
  (let
    (
      (proposal-id (+ (var-get proposal-counter) u1))
    )
    (map-set proposals proposal-id {
      proposer: tx-sender,
      title: title,
      description: description,
      votes-for: u0,
      votes-against: u0,
      status: STATUS-ACTIVE,
      created-at: block-height,
      ends-at: (+ block-height VOTING-PERIOD)
    })
    
    (var-set proposal-counter proposal-id)
    (ok proposal-id)
  )
)

(define-public (vote (proposal-id uint) (vote-for bool))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
      (already-voted (map-get? votes { proposal-id: proposal-id, voter: tx-sender }))
    )
    (asserts! (is-eq (get status proposal) STATUS-ACTIVE) ERR-VOTING-CLOSED)
    (asserts! (< block-height (get ends-at proposal)) ERR-VOTING-CLOSED)
    (asserts! (is-none already-voted) ERR-ALREADY-VOTED)
    
    ;; Record vote
    (map-set votes { proposal-id: proposal-id, voter: tx-sender } vote-for)
    
    ;; Update vote counts
    (map-set proposals proposal-id (merge proposal {
      votes-for: (if vote-for (+ (get votes-for proposal) u1) (get votes-for proposal)),
      votes-against: (if vote-for (get votes-against proposal) (+ (get votes-against proposal) u1))
    }))
    
    (ok true)
  )
)

(define-public (finalize-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
      (total-votes (+ (get votes-for proposal) (get votes-against proposal)))
      (passed (and 
        (>= total-votes QUORUM-THRESHOLD)
        (> (* (get votes-for proposal) u100) (* total-votes PASS-THRESHOLD))))
    )
    (asserts! (is-eq (get status proposal) STATUS-ACTIVE) ERR-VOTING-CLOSED)
    (asserts! (>= block-height (get ends-at proposal)) ERR-VOTING-OPEN)
    
    (map-set proposals proposal-id (merge proposal {
      status: (if passed STATUS-PASSED STATUS-FAILED)
    }))
    
    (ok passed)
  )
)


;; ============================================
;; Read Functions
;; ============================================

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-proposal-count)
  (var-get proposal-counter)
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (has-voted (proposal-id uint) (voter principal))
  (is-some (map-get? votes { proposal-id: proposal-id, voter: voter }))
)

(define-read-only (is-proposal-active (proposal-id uint))
  (match (map-get? proposals proposal-id)
    p (and (is-eq (get status p) STATUS-ACTIVE) (< block-height (get ends-at p)))
    false
  )
)
