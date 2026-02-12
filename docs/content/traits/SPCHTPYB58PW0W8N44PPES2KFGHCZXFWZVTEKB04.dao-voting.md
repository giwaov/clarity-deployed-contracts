---
title: "Trait dao-voting"
draft: true
---
```
;; Simple DAO Voting Contract
;; Members can create and vote on proposals

(define-constant contract-owner tx-sender)
(define-constant err-not-member (err u100))
(define-constant err-already-voted (err u101))
(define-constant err-proposal-not-found (err u102))
(define-constant err-voting-closed (err u103))

(define-data-var proposal-count uint u0)
(define-data-var voting-period uint u144) ;; ~1 day in blocks

(define-map members principal bool)
(define-map proposals
    uint
    {
        proposer: principal,
        title: (string-ascii 50),
        description: (string-ascii 500),
        votes-for: uint,
        votes-against: uint,
        start-block: uint,
        executed: bool
    }
)
(define-map votes {proposal-id: uint, voter: principal} bool)

;; Add member (only owner)
(define-public (add-member (member principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-member)
        (ok (map-set members member true))
    )
)

;; Create proposal
(define-public (create-proposal (title (string-ascii 50)) (description (string-ascii 500)))
    (let
        (
            (proposal-id (var-get proposal-count))
        )
        (asserts! (default-to false (map-get? members tx-sender)) err-not-member)
        (map-set proposals proposal-id {
            proposer: tx-sender,
            title: title,
            description: description,
            votes-for: u0,
            votes-against: u0,
            start-block: block-height,
            executed: false
        })
        (var-set proposal-count (+ proposal-id u1))
        (ok proposal-id)
    )
)

;; Vote on proposal
(define-public (vote (proposal-id uint) (support bool))
    (let
        (
            (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
            (voter-key {proposal-id: proposal-id, voter: tx-sender})
        )
        (asserts! (default-to false (map-get? members tx-sender)) err-not-member)
        (asserts! (is-none (map-get? votes voter-key)) err-already-voted)
        (asserts! (< (- block-height (get start-block proposal)) (var-get voting-period)) err-voting-closed)
        
        (map-set votes voter-key true)
        (if support
            (map-set proposals proposal-id (merge proposal {votes-for: (+ (get votes-for proposal) u1)}))
            (map-set proposals proposal-id (merge proposal {votes-against: (+ (get votes-against proposal) u1)}))
        )
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals proposal-id)
)

(define-read-only (has-voted (proposal-id uint) (voter principal))
    (is-some (map-get? votes {proposal-id: proposal-id, voter: voter}))
)

(define-read-only (is-member (account principal))
    (default-to false (map-get? members account))
)

;; Initialize contract owner as member
(map-set members contract-owner true)

```
