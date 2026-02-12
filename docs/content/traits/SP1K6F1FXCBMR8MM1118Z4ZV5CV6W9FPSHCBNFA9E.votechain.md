---
title: "Trait votechain"
draft: true
---
```
;; VoteChain: A decentralized voting system

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ALREADY_VOTED (err u101))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u102))
(define-constant ERR_VOTING_CLOSED (err u103))
(define-constant ERR_INVALID_TITLE (err u104))
(define-constant ERR_INVALID_DESCRIPTION (err u105))
(define-constant ERR_INVALID_DURATION (err u106))

;; Data maps
(define-map proposals
  { proposal-id: uint }
  { 
    title: (string-ascii 50),
    description: (string-ascii 280),
    creator: principal,
    yes-votes: uint,
    no-votes: uint,
    end-block: uint
  }
)

(define-map votes
  { voter: principal, proposal-id: uint }
  { vote: bool }
)

;; Variables
(define-data-var proposal-nonce uint u0)

;; Read-only functions
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

(define-read-only (get-proposal-count)
  (var-get proposal-nonce)
)

(define-read-only (get-vote (voter principal) (proposal-id uint))
  (map-get? votes { voter: voter, proposal-id: proposal-id })
)

(define-read-only (is-voting-open (proposal-id uint))
  (let ((proposal (unwrap! (get-proposal proposal-id) false)))
    (< stacks-block-height (get end-block proposal))
  )
)

;; Private functions
(define-private (validate-string-length (str (string-ascii 280)) (min uint) (max uint))
  (let ((len (len str)))
    (and (>= len min) (<= len max))
  )
)

;; Public functions
(define-public (create-proposal (title (string-ascii 50)) (description (string-ascii 280)) (duration uint))
  (let
    (
      (new-proposal-id (+ (var-get proposal-nonce) u1))
      (end-block (+ stacks-block-height duration))
    )
    ;; Input validation
    (asserts! (validate-string-length title u1 u50) ERR_INVALID_TITLE)
    (asserts! (validate-string-length description u1 u280) ERR_INVALID_DESCRIPTION)
    (asserts! (and (> duration u0) (<= duration u10000)) ERR_INVALID_DURATION)
    
    (map-set proposals
      { proposal-id: new-proposal-id }
      {
        title: title,
        description: description,
        creator: tx-sender,
        yes-votes: u0,
        no-votes: u0,
        end-block: end-block
      }
    )
    (var-set proposal-nonce new-proposal-id)
    (ok new-proposal-id)
  )
)

(define-public (vote (proposal-id uint) (vote-bool bool))
  (let
    (
      (proposal (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND))
    )
    (asserts! (is-voting-open proposal-id) ERR_VOTING_CLOSED)
    (asserts! (is-none (get-vote tx-sender proposal-id)) ERR_ALREADY_VOTED)
    (map-set votes
      { voter: tx-sender, proposal-id: proposal-id }
      { vote: vote-bool }
    )
    (if vote-bool
      (map-set proposals
        { proposal-id: proposal-id }
        (merge proposal { yes-votes: (+ (get yes-votes proposal) u1) })
      )
      (map-set proposals
        { proposal-id: proposal-id }
        (merge proposal { no-votes: (+ (get no-votes proposal) u1) })
      )
    )
    (ok true)
  )
)

;; Admin functions
(define-public (close-voting (proposal-id uint))
  (let
    (
      (proposal (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (>= stacks-block-height (get end-block proposal)) ERR_VOTING_CLOSED)
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { end-block: stacks-block-height })
    )
    (ok true)
  )
)
```
