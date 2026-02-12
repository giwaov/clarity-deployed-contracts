---
title: "Trait voting"
draft: true
---
```
;; ---------------------------------------------------------
;; Voting Contract
;; Clarity Version: 4
;; ---------------------------------------------------------

;; -------------------------
;; ERROR CODES
;; -------------------------
(define-constant ERR_UNAUTHORIZED        (err u100))
(define-constant ERR_INVALID_PROPOSAL    (err u101))
(define-constant ERR_VOTING_CLOSED       (err u102))
(define-constant ERR_ALREADY_VOTED       (err u103))
(define-constant ERR_INVALID_CHOICE      (err u104))
(define-constant ERR_INVALID_DURATION    (err u105))
(define-constant ERR_ALREADY_EXECUTED    (err u106))

;; -------------------------
;; CONSTANTS
;; -------------------------
(define-constant MIN_VOTING_PERIOD u10)
(define-constant MAX_CHOICES u10)

;; -------------------------
;; DATA STORAGE
;; -------------------------
(define-data-var proposal-count uint u0)
(define-data-var contract-owner principal tx-sender)

;; -------------------------
;; MAPS
;; -------------------------
(define-map proposals
  { id: uint }
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 1000),
    choices: (list 10 (string-ascii 50)),
    end-block: uint,
    executed: bool,
    total-votes: uint
  }
)

(define-map votes
  { proposal-id: uint, voter: principal }
  { choice: uint }
)

(define-map vote-counts
  { proposal-id: uint, choice: uint }
  uint
)

;; -------------------------
;; PRIVATE HELPERS
;; -------------------------

(define-private (proposal-active?
  (proposal
    {
      creator: principal,
      title: (string-ascii 100),
      description: (string-ascii 1000),
      choices: (list 10 (string-ascii 50)),
      end-block: uint,
      executed: bool,
      total-votes: uint
    }
  )
)
  (and
    (not (get executed proposal))
    ;; Use stacks-block-height instead of block-height
    (< stacks-block-height (get end-block proposal))
  )
)

;; -------------------------
;; PUBLIC FUNCTIONS
;; -------------------------

;; Create proposal
(define-public (create-proposal
  (title (string-ascii 100))
  (description (string-ascii 1000))
  (choices (list 10 (string-ascii 50)))
  (duration uint))
  (let (
    (choice-count (len choices))
  )
    (asserts! (>= duration MIN_VOTING_PERIOD) ERR_INVALID_DURATION)
    (asserts! (>= choice-count u2) ERR_INVALID_CHOICE)
    (asserts! (<= choice-count MAX_CHOICES) ERR_INVALID_CHOICE)

    (let ((id (+ (var-get proposal-count) u1)))
      (var-set proposal-count id)

      (map-set proposals { id: id } {
        creator: tx-sender,
        title: title,
        description: description,
        choices: choices,
        end-block: (+ stacks-block-height duration),
        executed: false,
        total-votes: u0
      })

      (ok id)
    )
  )
)

;; Vote
(define-public (vote (proposal-id uint) (choice uint))
  (let (
    (proposal (unwrap! (map-get? proposals { id: proposal-id }) ERR_INVALID_PROPOSAL))
    (voter tx-sender)
  )
    (asserts! (proposal-active? proposal) ERR_VOTING_CLOSED)
    (asserts! (is-none (map-get? votes { proposal-id: proposal-id, voter: voter })) ERR_ALREADY_VOTED)
    (asserts! (< choice (len (get choices proposal))) ERR_INVALID_CHOICE)

    ;; record vote
    (map-set votes { proposal-id: proposal-id, voter: voter }
      { choice: choice })

    ;; update counts
    (map-set vote-counts
      { proposal-id: proposal-id, choice: choice }
      (+ u1 (default-to u0 (map-get? vote-counts { proposal-id: proposal-id, choice: choice })))
    )

    ;; update proposal
    (map-set proposals { id: proposal-id }
      (merge proposal { total-votes: (+ (get total-votes proposal) u1) })
    )

    (ok true)
  )
)

;; Execute proposal
(define-public (execute-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals { id: proposal-id }) ERR_INVALID_PROPOSAL)))
    (asserts! (not (get executed proposal)) ERR_ALREADY_EXECUTED)
    (asserts! (>= stacks-block-height (get end-block proposal)) ERR_VOTING_CLOSED)

    (map-set proposals { id: proposal-id }
      (merge proposal { executed: true })
    )

    (ok true)
  )
)

;; -------------------------
;; READ-ONLY FUNCTIONS
;; -------------------------

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { id: proposal-id })
)

(define-read-only (get-vote-count (proposal-id uint) (choice uint))
  (default-to u0 (map-get? vote-counts { proposal-id: proposal-id, choice: choice }))
)

(define-read-only (get-user-vote (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (is-voting-active (proposal-id uint))
  (match (map-get? proposals { id: proposal-id })
    proposal (proposal-active? proposal)
    false
  )
)

(define-read-only (get-proposal-count)
  (var-get proposal-count)
)

```
