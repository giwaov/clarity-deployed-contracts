;; DAO Proposal System
;; Manages proposal creation, voting, and execution

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-proposal-not-found (err u201))
(define-constant err-already-voted (err u202))
(define-constant err-voting-closed (err u203))
(define-constant err-proposal-not-passed (err u204))
(define-constant err-proposal-already-executed (err u205))
(define-constant err-insufficient-voting-power (err u206))
(define-constant err-voting-still-active (err u207))
(define-constant err-quorum-not-met (err u208))

;; Governance parameters
(define-constant quorum-percentage u15) ;; 15%
(define-constant passing-threshold u51) ;; 51%
(define-constant voting-period u1008) ;; ~7 days in blocks (assuming 10 min blocks)

;; Data variables
(define-data-var proposal-count uint u0)
(define-data-var governance-token-contract principal .governance-token)

;; Proposal status
(define-constant status-active u1)
(define-constant status-passed u2)
(define-constant status-failed u3)
(define-constant status-executed u4)
(define-constant status-cancelled u5)

;; Data maps
(define-map proposals
    uint
    {
        proposer: principal,
        title: (string-ascii 100),
        description: (string-utf8 500),
        votes-for: uint,
        votes-against: uint,
        start-block: uint,
        end-block: uint,
        status: uint,
        execution-delay: uint,
        target-contract: (optional principal),
        target-function: (optional (string-ascii 50))
    }
)

(define-map votes { proposal-id: uint, voter: principal } { amount: uint, vote-for: bool })
(define-map voter-snapshots { proposal-id: uint, voter: principal } uint)

;; Create a new proposal
(define-public (create-proposal 
    (title (string-ascii 100))
    (description (string-utf8 500))
    (execution-delay uint)
    (target-contract (optional principal))
    (target-function (optional (string-ascii 50)))
)
    (let (
        (proposal-id (+ (var-get proposal-count) u1))
        (start-block stacks-block-height)
        (end-block (+ stacks-block-height voting-period))
    )
        (map-set proposals proposal-id {
            proposer: tx-sender,
            title: title,
            description: description,
            votes-for: u0,
            votes-against: u0,
            start-block: start-block,
            end-block: end-block,
            status: status-active,
            execution-delay: execution-delay,
            target-contract: target-contract,
            target-function: target-function
        })
        (var-set proposal-count proposal-id)
        (print { event: "proposal-created", proposal-id: proposal-id, proposer: tx-sender })
        (ok proposal-id)
    )
)

;; Cast a vote on a proposal
(define-public (vote (proposal-id uint) (vote-for bool) (amount uint))
    (let (
        (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
        (voter-power amount)
    )
        ;; Validate voting conditions
        (asserts! (is-none (map-get? votes { proposal-id: proposal-id, voter: tx-sender })) err-already-voted)
        (asserts! (< stacks-block-height (get end-block proposal)) err-voting-closed)
        (asserts! (is-eq (get status proposal) status-active) err-voting-closed)
        (asserts! (> voter-power u0) err-insufficient-voting-power)
        
        ;; Record the vote
        (map-set votes 
            { proposal-id: proposal-id, voter: tx-sender }
            { amount: voter-power, vote-for: vote-for }
        )
        
        ;; Update proposal vote counts
        (map-set proposals proposal-id
            (merge proposal {
                votes-for: (if vote-for 
                    (+ (get votes-for proposal) voter-power)
                    (get votes-for proposal)
                ),
                votes-against: (if vote-for
                    (get votes-against proposal)
                    (+ (get votes-against proposal) voter-power)
                )
            })
        )
        
        (print { 
            event: "vote-cast", 
            proposal-id: proposal-id, 
            voter: tx-sender, 
            vote-for: vote-for,
            amount: voter-power
        })
        (ok true)
    )
)

;; Finalize proposal after voting period
(define-public (finalize-proposal (proposal-id uint))
    (let (
        (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
        (total-votes (+ (get votes-for proposal) (get votes-against proposal)))
        (total-supply u1000000000000) ;; Should query from governance token
        (quorum-required (/ (* total-supply quorum-percentage) u100))
        (votes-for (get votes-for proposal))
        (votes-against (get votes-against proposal))
    )
        (asserts! (>= stacks-block-height (get end-block proposal)) err-voting-still-active)
        (asserts! (is-eq (get status proposal) status-active) err-voting-closed)
        
        ;; Check quorum and passing threshold
        (if (and 
                (>= total-votes quorum-required)
                (>= (* votes-for u100) (* (+ votes-for votes-against) passing-threshold))
            )
            (begin
                (map-set proposals proposal-id (merge proposal { status: status-passed }))
                (print { event: "proposal-passed", proposal-id: proposal-id })
                (ok status-passed)
            )
            (begin
                (map-set proposals proposal-id (merge proposal { status: status-failed }))
                (print { event: "proposal-failed", proposal-id: proposal-id })
                (ok status-failed)
            )
        )
    )
)

;; Execute a passed proposal
(define-public (execute-proposal (proposal-id uint))
    (let (
        (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
    )
        (asserts! (is-eq (get status proposal) status-passed) err-proposal-not-passed)
        (asserts! (>= stacks-block-height (+ (get end-block proposal) (get execution-delay proposal))) err-voting-still-active)
        
        (map-set proposals proposal-id (merge proposal { status: status-executed }))
        (print { event: "proposal-executed", proposal-id: proposal-id })
        (ok true)
    )
)

;; Cancel a proposal (only by proposer or owner)
(define-public (cancel-proposal (proposal-id uint))
    (let (
        (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
    )
        (asserts! 
            (or 
                (is-eq tx-sender (get proposer proposal))
                (is-eq tx-sender contract-owner)
            )
            err-owner-only
        )
        (asserts! (is-eq (get status proposal) status-active) err-proposal-already-executed)
        
        (map-set proposals proposal-id (merge proposal { status: status-cancelled }))
        (print { event: "proposal-cancelled", proposal-id: proposal-id })
        (ok true)
    )
)

;; Read-only functions

(define-read-only (get-proposal (proposal-id uint))
    (ok (map-get? proposals proposal-id))
)

(define-read-only (get-proposal-count)
    (ok (var-get proposal-count))
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
    (ok (map-get? votes { proposal-id: proposal-id, voter: voter }))
)

(define-read-only (has-voted (proposal-id uint) (voter principal))
    (ok (is-some (map-get? votes { proposal-id: proposal-id, voter: voter })))
)

(define-read-only (get-proposal-status (proposal-id uint))
    (ok (get status (unwrap! (map-get? proposals proposal-id) err-proposal-not-found)))
)

(define-read-only (is-voting-active (proposal-id uint))
    (match (map-get? proposals proposal-id)
        proposal
            (ok (and 
                (< stacks-block-height (get end-block proposal))
                (is-eq (get status proposal) status-active)
            ))
        err-proposal-not-found
    )
)

(define-read-only (get-voting-results (proposal-id uint))
    (match (map-get? proposals proposal-id)
        proposal
            (ok {
                votes-for: (get votes-for proposal),
                votes-against: (get votes-against proposal),
                total-votes: (+ (get votes-for proposal) (get votes-against proposal)),
                status: (get status proposal)
            })
        err-proposal-not-found
    )
)
