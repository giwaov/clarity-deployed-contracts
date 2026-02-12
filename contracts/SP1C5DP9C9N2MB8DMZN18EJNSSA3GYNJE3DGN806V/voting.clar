;; Voting Smart Contract using Clarity 4 Features
;; This contract implements a decentralized voting system with proposal creation and voting

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-voted (err u102))
(define-constant err-voting-ended (err u103))
(define-constant err-voting-not-ended (err u104))
(define-constant err-unauthorized (err u105))
(define-constant err-invalid-duration (err u106))
(define-constant err-not-started (err u107))
(define-constant err-already-executed (err u108))

;; Data Variables
(define-data-var proposal-counter uint u0)

;; Data Maps
(define-map proposals
    uint
    {
        title: (string-utf8 100),
        description: (string-utf8 500),
        proposer: principal,
        yes-votes: uint,
        no-votes: uint,
        start-block: uint,
        end-block: uint,
        executed: bool
    }
)

(define-map votes
    {proposal-id: uint, voter: principal}
    {vote: bool, weight: uint}
)

(define-map voter-weights
    principal
    uint
)

;; Public Functions

;; Create a new proposal (Clarity 4: improved string handling)
(define-public (create-proposal (title (string-utf8 100)) (description (string-utf8 500)) (duration uint))
    (let
        (
            (proposal-id (+ (var-get proposal-counter) u1))
            (start-block stacks-block-height)
            (end-block (+ stacks-block-height duration))
        )
        (asserts! (> duration u0) err-invalid-duration)
        (map-set proposals proposal-id {
            title: title,
            description: description,
            proposer: tx-sender,
            yes-votes: u0,
            no-votes: u0,
            start-block: start-block,
            end-block: end-block,
            executed: false
        })
        (var-set proposal-counter proposal-id)
        (ok proposal-id)
    )
)

;; Cast vote on a proposal (Clarity 4: enhanced map operations)
(define-public (cast-vote (proposal-id uint) (vote-choice bool))
    (let
        (
            (proposal (unwrap! (map-get? proposals proposal-id) err-not-found))
            (voter-weight (default-to u1 (map-get? voter-weights tx-sender)))
            (has-voted (is-some (map-get? votes {proposal-id: proposal-id, voter: tx-sender})))
        )
        ;; Check if already voted
        (asserts! (not has-voted) err-already-voted)
        
        ;; Check if voting is still active
        (asserts! (<= stacks-block-height (get end-block proposal)) err-voting-ended)
        (asserts! (>= stacks-block-height (get start-block proposal)) err-not-started)
        
        ;; Record the vote
        (map-set votes 
            {proposal-id: proposal-id, voter: tx-sender}
            {vote: vote-choice, weight: voter-weight}
        )
        
        ;; Update vote counts using merge (Clarity 4 feature)
        (if vote-choice
            (map-set proposals proposal-id 
                (merge proposal {yes-votes: (+ (get yes-votes proposal) voter-weight)})
            )
            (map-set proposals proposal-id 
                (merge proposal {no-votes: (+ (get no-votes proposal) voter-weight)})
            )
        )
        (ok true)
    )
)

;; Set voter weight (only contract owner)
(define-public (set-voter-weight (voter principal) (weight uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set voter-weights voter weight))
    )
)

;; Execute proposal (mark as executed after voting ends)
(define-public (execute-proposal (proposal-id uint))
    (let
        (
            (proposal (unwrap! (map-get? proposals proposal-id) err-not-found))
        )
        ;; Check if voting has ended
        (asserts! (> stacks-block-height (get end-block proposal)) err-voting-not-ended)
        
        ;; Check if not already executed
        (asserts! (not (get executed proposal)) err-already-executed)
        
        ;; Mark as executed using merge
        (map-set proposals proposal-id (merge proposal {executed: true}))
        
        ;; Return result
        (ok {
            proposal-id: proposal-id,
            passed: (> (get yes-votes proposal) (get no-votes proposal)),
            yes-votes: (get yes-votes proposal),
            no-votes: (get no-votes proposal)
        })
    )
)

;; Read-only Functions

;; Get proposal details (Clarity 4: improved optional handling)
(define-read-only (get-proposal (proposal-id uint))
    (ok (map-get? proposals proposal-id))
)

;; Get vote details for a specific voter
(define-read-only (get-vote (proposal-id uint) (voter principal))
    (ok (map-get? votes {proposal-id: proposal-id, voter: voter}))
)

;; Get voter weight
(define-read-only (get-voter-weight (voter principal))
    (ok (default-to u1 (map-get? voter-weights voter)))
)

;; Get total number of proposals
(define-read-only (get-proposal-count)
    (ok (var-get proposal-counter))
)

;; Check if proposal is active (Clarity 4: match expression)
(define-read-only (is-proposal-active (proposal-id uint))
    (match (map-get? proposals proposal-id)
        proposal (ok (and 
            (>= stacks-block-height (get start-block proposal))
            (<= stacks-block-height (get end-block proposal))
            (not (get executed proposal))
        ))
        (ok false)
    )
)

;; Get proposal result
(define-read-only (get-proposal-result (proposal-id uint))
    (match (map-get? proposals proposal-id)
        proposal (ok {
            yes-votes: (get yes-votes proposal),
            no-votes: (get no-votes proposal),
            total-votes: (+ (get yes-votes proposal) (get no-votes proposal)),
            passed: (> (get yes-votes proposal) (get no-votes proposal)),
            executed: (get executed proposal)
        })
        err-not-found
    )
)
