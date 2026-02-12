---
title: "Trait stackpol"
draft: true
---
```
;; StackPoll - Decentralized On-Chain Polling Contract
;; Fully permissionless polling system for Stacks blockchain

;; Error constants
(define-constant err-empty-question (err u100))
(define-constant err-invalid-options (err u101))
(define-constant err-empty-option (err u102))
(define-constant err-poll-not-found (err u103))
(define-constant err-invalid-option-index (err u104))
(define-constant err-already-voted (err u105))

;; Data variables
(define-data-var next-poll-id uint u1)

;; Data maps
(define-map polls
    uint
    {
        creator: principal,
        question: (string-ascii 200),
        options: (list 6 (string-ascii 100)),
        created-at: uint
    }
)

(define-map votes
    { poll-id: uint, voter: principal }
    uint
)

(define-map vote-counts
    { poll-id: uint, option-index: uint }
    uint
)

;; Private helper functions
(define-private (is-valid-options (options (list 6 (string-ascii 100))))
    (let ((len (len options)))
        (and (>= len u2) (<= len u6))
    )
)

(define-private (is-non-empty-string (str (string-ascii 100)))
    (> (len str) u0)
)

(define-private (all-options-non-empty (options (list 6 (string-ascii 100))))
    (is-eq (len (filter is-non-empty-string options)) (len options))
)

(define-private (increment-vote-count (poll-id uint) (option-index uint))
    (let ((current-count (default-to u0 (map-get? vote-counts { poll-id: poll-id, option-index: option-index }))))
        (map-set vote-counts { poll-id: poll-id, option-index: option-index } (+ current-count u1))
    )
)

(define-private (get-option-vote-count (poll-id uint) (option-index uint))
    (default-to u0 (map-get? vote-counts { poll-id: poll-id, option-index: option-index }))
)

;; Public functions
(define-public (create-poll (question (string-ascii 200)) (options (list 6 (string-ascii 100))))
    (let
        (
            (poll-id (var-get next-poll-id))
        )
        (asserts! (> (len question) u0) err-empty-question)
        (asserts! (is-valid-options options) err-invalid-options)
        (asserts! (all-options-non-empty options) err-empty-option)
        
        (map-set polls poll-id {
            creator: tx-sender,
            question: question,
            options: options,
            created-at: stacks-block-height
        })
        
        (var-set next-poll-id (+ poll-id u1))
        (ok poll-id)
    )
)

(define-public (vote (poll-id uint) (option-index uint))
    (let
        (
            (poll (unwrap! (map-get? polls poll-id) err-poll-not-found))
            (vote-key { poll-id: poll-id, voter: tx-sender })
            (options-len (len (get options poll)))
        )
        (asserts! (< option-index options-len) err-invalid-option-index)
        (asserts! (is-none (map-get? votes vote-key)) err-already-voted)
        
        (map-set votes vote-key option-index)
        (increment-vote-count poll-id option-index)
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-poll (poll-id uint))
    (map-get? polls poll-id)
)

(define-read-only (get-vote-counts (poll-id uint))
    (match (map-get? polls poll-id)
        poll-data
            (ok (list
                (get-option-vote-count poll-id u0)
                (get-option-vote-count poll-id u1)
                (get-option-vote-count poll-id u2)
                (get-option-vote-count poll-id u3)
                (get-option-vote-count poll-id u4)
                (get-option-vote-count poll-id u5)
            ))
        err-poll-not-found
    )
)

(define-read-only (has-voted (poll-id uint) (user principal))
    (is-some (map-get? votes { poll-id: poll-id, voter: user }))
)

(define-read-only (get-user-vote (poll-id uint) (user principal))
    (map-get? votes { poll-id: poll-id, voter: user })
)

(define-read-only (get-total-polls)
    (- (var-get next-poll-id) u1)
)

(define-read-only (get-poll-summary (poll-id uint))
    (match (map-get? polls poll-id)
        poll-data
            (let
                (
                    (total-votes (fold + (unwrap-panic (get-vote-counts poll-id)) u0))
                )
                (some {
                    id: poll-id,
                    question: (get question poll-data),
                    creator: (get creator poll-data),
                    created-at: (get created-at poll-data),
                    total-votes: total-votes,
                    option-count: (len (get options poll-data))
                })
            )
        none
    )
)

(define-read-only (get-next-poll-id)
    (var-get next-poll-id)
)
```
