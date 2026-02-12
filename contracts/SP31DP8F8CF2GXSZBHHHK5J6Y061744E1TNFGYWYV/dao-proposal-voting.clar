
;; dao-proposal-voting.clar
;; Standard proposal creation and voting mechanism.
;; CLARITY VERSION: 4

(use-trait governance-token-trait .governance-token-trait.governance-token-trait)

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-VOTED (err u102))
(define-constant ERR-VOTING-CLOSED (err u103))
(define-constant ERR-INSUFFICIENT-VOTES (err u104))

(define-map proposals
    uint
    {
        proposer: principal,
        title: (string-ascii 50),
        description: (string-utf8 256),
        start-block: uint,
        end-block: uint,
        yes-votes: uint,
        no-votes: uint,
        executed: bool
    }
)

(define-map votes
    {proposal-id: uint, voter: principal}
    bool
)

(define-data-var proposal-count uint u0)
(define-data-var voting-delay uint u144) ;; ~1 day
(define-data-var voting-period uint u1008) ;; ~1 week

(define-public (create-proposal (title (string-ascii 50)) (description (string-utf8 256)) (token-trait <governance-token-trait>))
    (let (
        (id (var-get proposal-count))
        (start (+ stacks-block-height (var-get voting-delay)))
        (end (+ start (var-get voting-period)))
        (threshold u100) ;; Min tokens to propose
    )
    ;; Check proposer balance at current block (or previous) to prevent spam
    (asserts! (>= (unwrap-panic (contract-call? token-trait get-balance tx-sender)) threshold) ERR-NOT-AUTHORIZED)

    (map-set proposals id {
        proposer: tx-sender,
        title: title,
        description: description,
        start-block: start,
        end-block: end,
        yes-votes: u0,
        no-votes: u0,
        executed: false
    })
    (var-set proposal-count (+ id u1))
    (ok id))
)

(define-public (vote (proposal-id uint) (vote-for bool) (token-trait <governance-token-trait>))
    (let (
        (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
        (voter tx-sender)
        (has-voted (default-to false (map-get? votes {proposal-id: proposal-id, voter: voter})))
    )
    (asserts! (not has-voted) ERR-ALREADY-VOTED)
    (asserts! (<= stacks-block-height (get end-block proposal)) ERR-VOTING-CLOSED)
    (asserts! (>= stacks-block-height (get start-block proposal)) (err u105))

    (let (
        ;; Get voting power at start-block of proposal to prevent flash loan attacks
        (voting-power (unwrap-panic (contract-call? token-trait get-balance-at-block voter (get start-block proposal))))
    )
        (asserts! (> voting-power u0) ERR-NOT-AUTHORIZED)
        
        (map-set proposals proposal-id
            (merge proposal {
                yes-votes: (if vote-for (+ (get yes-votes proposal) voting-power) (get yes-votes proposal)),
                no-votes: (if vote-for (get no-votes proposal) (+ (get no-votes proposal) voting-power))
            })
        )
        (map-set votes {proposal-id: proposal-id, voter: voter} true)
        (ok voting-power)
    )
    )
)

(define-public (execute (proposal-id uint))
    (let (
        (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
    )
    (asserts! (> stacks-block-height (get end-block proposal)) (err u106))
    (asserts! (not (get executed proposal)) (err u107))
    (asserts! (> (get yes-votes proposal) (get no-votes proposal)) ERR-INSUFFICIENT-VOTES)

    ;; Execute logic would go here (e.g., contract-call to target)
    ;; For this example, just mark as executed.
    
    (map-set proposals proposal-id (merge proposal { executed: true }))
    (ok true))
)
