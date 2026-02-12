;; Governance Contract
;; Handles proposals, voting, and milestone verification

(define-constant ERR-UNAUTHORIZED (err u4001))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u4002))
(define-constant ERR-ALREADY-VOTED (err u4003))
(define-constant ERR-VOTING-CLOSED (err u4004))
(define-constant ERR-INVALID-PROPOSAL (err u4005))

(define-constant VOTING-DURATION u604800) ;; 7 days in seconds
(define-constant MIN-VOTING-POWER u100) ;; Minimum tokens required to vote

;; Proposal types: 0 = startup approval, 1 = milestone verification, 2 = platform parameter, 3 = other
(define-map proposals
    { proposal-id: uint }
    {
        proposer: principal,
        proposal-type: uint,
        title: (string-ascii 100),
        description: (string-utf8 1000),
        target-id: uint, ;; startup-id or milestone-id depending on type
        created-at: uint,
        voting-end: uint,
        status: uint, ;; 0: active, 1: passed, 2: rejected, 3: executed
        yes-votes: uint,
        no-votes: uint,
        total-votes: uint
    }
)

;; Votes tracking
(define-map votes
    { proposal-id: uint, voter: principal }
    {
        vote: uint, ;; 0 = no, 1 = yes
        voting-power: uint,
        voted-at: uint
    }
)

(define-data-var next-proposal-id uint u1)

;; Create a proposal
(define-public (create-proposal
    (proposal-type uint)
    (title (string-ascii 100))
    (description (string-utf8 1000))
    (target-id uint)
)
    (let
        (
            (proposal-id (var-get next-proposal-id))
            (timestamp (unwrap! (get-block-info? time u0) ERR-UNAUTHORIZED))
            (voting-end (+ timestamp VOTING-DURATION))
        )
        (asserts! (<= proposal-type u3) ERR-INVALID-PROPOSAL)
        (begin
            (map-set proposals
                { proposal-id: proposal-id }
                {
                    proposer: tx-sender,
                    proposal-type: proposal-type,
                    title: title,
                    description: description,
                    target-id: target-id,
                    created-at: timestamp,
                    voting-end: voting-end,
                    status: u0,
                    yes-votes: u0,
                    no-votes: u0,
                    total-votes: u0
                }
            )
            (var-set next-proposal-id (+ proposal-id u1))
            (ok proposal-id)
        )
    )
)

;; Vote on a proposal
(define-public (vote
    (proposal-id uint)
    (vote-choice uint) ;; 0 = no, 1 = yes
    (voting-power uint)
)
    (let
        (
            (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
            (timestamp (unwrap! (get-block-info? time u0) ERR-UNAUTHORIZED))
            (existing-vote (map-get? votes { proposal-id: proposal-id, voter: tx-sender }))
        )
        (asserts! (is-eq (get status proposal) u0) ERR-VOTING-CLOSED)
        (asserts! (>= timestamp (get created-at proposal)) ERR-UNAUTHORIZED)
        (asserts! (<= timestamp (get voting-end proposal)) ERR-VOTING-CLOSED)
        (asserts! (>= voting-power MIN-VOTING-POWER) ERR-UNAUTHORIZED)
        (asserts! (is-none existing-vote) ERR-ALREADY-VOTED)
        (asserts! (or (is-eq vote-choice u0) (is-eq vote-choice u1)) ERR-INVALID-PROPOSAL)
        (let
            (
                (new-yes-votes (if (is-eq vote-choice u1) (+ (get yes-votes proposal) voting-power) (get yes-votes proposal)))
                (new-no-votes (if (is-eq vote-choice u0) (+ (get no-votes proposal) voting-power) (get no-votes proposal)))
                (new-total-votes (+ (get total-votes proposal) voting-power))
            )
            (begin
                (map-set votes
                    { proposal-id: proposal-id, voter: tx-sender }
                    {
                        vote: vote-choice,
                        voting-power: voting-power,
                        voted-at: timestamp
                    }
                )
                (map-set proposals
                    { proposal-id: proposal-id }
                    {
                        proposer: (get proposer proposal),
                        proposal-type: (get proposal-type proposal),
                        title: (get title proposal),
                        description: (get description proposal),
                        target-id: (get target-id proposal),
                        created-at: (get created-at proposal),
                        voting-end: (get voting-end proposal),
                        status: (get status proposal),
                        yes-votes: new-yes-votes,
                        no-votes: new-no-votes,
                        total-votes: new-total-votes
                    }
                )
                (ok true)
            )
        )
    )
)

;; Execute proposal (after voting period ends)
(define-public (execute-proposal (proposal-id uint))
    (let
        (
            (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
            (timestamp (unwrap! (get-block-info? time u0) ERR-UNAUTHORIZED))
        )
        (asserts! (is-eq (get status proposal) u0) ERR-VOTING-CLOSED)
        (asserts! (> timestamp (get voting-end proposal)) ERR-VOTING-CLOSED)
        (let
            (
                (passed (>= (get yes-votes proposal) (get no-votes proposal)))
                (new-status (if passed u1 u2))
            )
            (ok (map-set proposals
                { proposal-id: proposal-id }
                {
                    proposer: (get proposer proposal),
                    proposal-type: (get proposal-type proposal),
                    title: (get title proposal),
                    description: (get description proposal),
                    target-id: (get target-id proposal),
                    created-at: (get created-at proposal),
                    voting-end: (get voting-end proposal),
                    status: new-status,
                    yes-votes: (get yes-votes proposal),
                    no-votes: (get no-votes proposal),
                    total-votes: (get total-votes proposal)
                }
            ))
        )
    )
)

;; Get proposal
(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals { proposal-id: proposal-id })
)

;; Get vote
(define-read-only (get-vote (proposal-id uint) (voter principal))
    (map-get? votes { proposal-id: proposal-id, voter: voter })
)

;; Check if proposal passed
(define-read-only (is-proposal-passed (proposal-id uint))
    (match (map-get? proposals { proposal-id: proposal-id })
        proposal (and
            (is-eq (get status proposal) u1)
            (>= (get yes-votes proposal) (get no-votes proposal))
        )
        false
    )
)

