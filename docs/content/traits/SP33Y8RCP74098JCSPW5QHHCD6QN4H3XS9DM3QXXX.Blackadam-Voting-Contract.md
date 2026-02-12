---
title: "Trait Blackadam-Voting-Contract"
draft: true
---
```
;; Blackadam Voting Contract
;; Allows users to create polls with yes/no options and vote once per poll

;; Error codes
(define-constant ERR-NOT-FOUND (err u100))
(define-constant ERR-ALREADY-VOTED (err u101))
(define-constant ERR-POLL-ENDED (err u102))
(define-constant ERR-POLL-NOT-ENDED (err u103))
(define-constant ERR-UNAUTHORIZED (err u104))
(define-constant ERR-POLL-STARTED (err u105))

;; Store the contract deployer as admin
(define-constant CONTRACT-ADMIN tx-sender)

;; Data variables
(define-data-var poll-count uint u0)

;; Data maps
;; Store poll information
(define-map polls
  { poll-id: uint }
  {
    creator: principal,
    title: (string-ascii 256),
    description: (string-ascii 1024),
    yes-votes: uint,
    no-votes: uint,
    end-block: uint,
    is-active: bool
  }
)

;; Track who has voted on which poll
(define-map votes
  { poll-id: uint, voter: principal }
  { vote: bool } ;; true = yes, false = no
)

;; Read-only functions

;; Get poll details
(define-read-only (get-poll (poll-id uint))
  (map-get? polls { poll-id: poll-id })
)

;; Check if user has voted
(define-read-only (has-voted (poll-id uint) (voter principal))
  (is-some (map-get? votes { poll-id: poll-id, voter: voter }))
)

;; Get user's vote
(define-read-only (get-user-vote (poll-id uint) (voter principal))
  (map-get? votes { poll-id: poll-id, voter: voter })
)

;; Get total poll count
(define-read-only (get-poll-count)
  (ok (var-get poll-count))
)

;; Check if poll is still active
(define-read-only (is-poll-active (poll-id uint))
  (match (map-get? polls { poll-id: poll-id })
    poll (ok (and (get is-active poll) (<= stacks-block-height (get end-block poll))))
    ERR-NOT-FOUND
  )
)

;; Public functions

;; Create a new poll
(define-public (create-poll (title (string-ascii 256)) (description (string-ascii 1024)) (duration uint))
  (let
    (
      (new-poll-id (var-get poll-count))
      (end-block (+ stacks-block-height duration))
    )
    (map-set polls
      { poll-id: new-poll-id }
      {
        creator: tx-sender,
        title: title,
        description: description,
        yes-votes: u0,
        no-votes: u0,
        end-block: end-block,
        is-active: true
      }
    )
    (var-set poll-count (+ new-poll-id u1))
    
    ;; Emit event
    (print {
      event: "poll-created",
      poll-id: new-poll-id,
      creator: tx-sender,
      title: title,
      end-block: end-block
    })
    
    (ok new-poll-id)
  )
)

;; Vote on a poll (true = yes, false = no)
(define-public (vote (poll-id uint) (vote-yes bool))
  (let
    (
      (poll (unwrap! (map-get? polls { poll-id: poll-id }) ERR-NOT-FOUND))
      (voter tx-sender)
    )
    ;; Check if user has already voted
    (asserts! (is-none (map-get? votes { poll-id: poll-id, voter: voter })) ERR-ALREADY-VOTED)
    
    ;; Check if poll is still active
    (asserts! (get is-active poll) ERR-POLL-ENDED)
    (asserts! (<= stacks-block-height (get end-block poll)) ERR-POLL-ENDED)
    
    ;; Record the vote
    (map-set votes
      { poll-id: poll-id, voter: voter }
      { vote: vote-yes }
    )
    
    ;; Update vote count
    (if vote-yes
      (map-set polls
        { poll-id: poll-id }
        (merge poll { yes-votes: (+ (get yes-votes poll) u1) })
      )
      (map-set polls
        { poll-id: poll-id }
        (merge poll { no-votes: (+ (get no-votes poll) u1) })
      )
    )
    
    ;; Emit event
    (print {
      event: "vote-cast",
      poll-id: poll-id,
      voter: voter,
      vote: (if vote-yes "yes" "no"),
      yes-votes: (if vote-yes (+ (get yes-votes poll) u1) (get yes-votes poll)),
      no-votes: (if vote-yes (get no-votes poll) (+ (get no-votes poll) u1))
    })
    
    (ok true)
  )
)

;; End a poll early (only creator can do this if no votes yet, admin can always do it)
(define-public (end-poll (poll-id uint))
  (let
    (
      (poll (unwrap! (map-get? polls { poll-id: poll-id }) ERR-NOT-FOUND))
      (total-votes (+ (get yes-votes poll) (get no-votes poll)))
      (is-admin (is-eq tx-sender CONTRACT-ADMIN))
      (is-creator (is-eq tx-sender (get creator poll)))
    )
    ;; Check if poll is active
    (asserts! (get is-active poll) ERR-POLL-ENDED)
    
    ;; Admin can close any poll anytime
    ;; Creator can only close if poll hasn't started (no votes yet)
    (asserts! 
      (or 
        is-admin 
        (and is-creator (is-eq total-votes u0))
      ) 
      (if (and is-creator (> total-votes u0))
        ERR-POLL-STARTED
        ERR-UNAUTHORIZED
      )
    )
    
    ;; Mark poll as inactive
    (map-set polls
      { poll-id: poll-id }
      (merge poll { is-active: false })
    )
    
    ;; Emit event
    (print {
      event: "poll-ended",
      poll-id: poll-id,
      ended-by: tx-sender,
      yes-votes: (get yes-votes poll),
      no-votes: (get no-votes poll),
      is-admin: is-admin
    })
    
    (ok true)
  )
)

;; Get poll results
(define-read-only (get-poll-results (poll-id uint))
  (match (map-get? polls { poll-id: poll-id })
    poll (ok {
      yes-votes: (get yes-votes poll),
      no-votes: (get no-votes poll),
      total-votes: (+ (get yes-votes poll) (get no-votes poll)),
      is-active: (and (get is-active poll) (<= stacks-block-height (get end-block poll))),
      end-block: (get end-block poll)
    })
    ERR-NOT-FOUND
  )
)

;; Check if caller is admin
(define-read-only (is-admin (user principal))
  (is-eq user CONTRACT-ADMIN)
)

;; Get admin address
(define-read-only (get-admin)
  (ok CONTRACT-ADMIN)
)
```
