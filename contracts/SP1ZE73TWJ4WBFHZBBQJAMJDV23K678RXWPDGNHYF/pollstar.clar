;; Pollstar - A Simple On-Chain Polling System
;; Create polls, vote, and track results on Stacks

;; Data storage
(define-map polls
  { poll-id: uint }
  {
    creator: principal,
    question: (string-ascii 200),
    option-a: (string-ascii 100),
    option-b: (string-ascii 100),
    votes-a: uint,
    votes-b: uint,
    end-block: uint,
    active: bool
  }
)

(define-map votes
  { poll-id: uint, voter: principal }
  { option: (string-ascii 1) }
)

(define-data-var poll-count uint u0)

;; Error codes
(define-constant ERR-POLL-NOT-FOUND (err u100))
(define-constant ERR-POLL-ENDED (err u101))
(define-constant ERR-ALREADY-VOTED (err u102))
(define-constant ERR-INVALID-OPTION (err u103))

;; Create a new poll
(define-public (create-poll 
    (question (string-ascii 200))
    (option-a (string-ascii 100))
    (option-b (string-ascii 100))
    (duration uint))
  (let
    (
      (new-id (+ (var-get poll-count) u1))
      (end-block (+ stacks-block-height duration))
    )
    (map-set polls
      { poll-id: new-id }
      {
        creator: tx-sender,
        question: question,
        option-a: option-a,
        option-b: option-b,
        votes-a: u0,
        votes-b: u0,
        end-block: end-block,
        active: true
      }
    )
    (var-set poll-count new-id)
    (ok new-id)
  )
)

;; Cast a vote
(define-public (vote (poll-id uint) (option (string-ascii 1)))
  (let
    (
      (poll (unwrap! (map-get? polls { poll-id: poll-id }) ERR-POLL-NOT-FOUND))
      (has-voted (map-get? votes { poll-id: poll-id, voter: tx-sender }))
    )
    ;; Check if already voted
    (asserts! (is-none has-voted) ERR-ALREADY-VOTED)
    
    ;; Check if poll is still active
    (asserts! (< stacks-block-height (get end-block poll)) ERR-POLL-ENDED)
    (asserts! (get active poll) ERR-POLL-ENDED)
    
    ;; Check valid option
    (asserts! (or (is-eq option "a") (is-eq option "b")) ERR-INVALID-OPTION)
    
    ;; Record vote
    (map-set votes
      { poll-id: poll-id, voter: tx-sender }
      { option: option }
    )
    
    ;; Update vote count
    (if (is-eq option "a")
      (map-set polls
        { poll-id: poll-id }
        (merge poll { votes-a: (+ (get votes-a poll) u1) })
      )
      (map-set polls
        { poll-id: poll-id }
        (merge poll { votes-b: (+ (get votes-b poll) u1) })
      )
    )
    (ok true)
  )
)

;; Close a poll (only creator can close early)
(define-public (close-poll (poll-id uint))
  (let
    (
      (poll (unwrap! (map-get? polls { poll-id: poll-id }) ERR-POLL-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get creator poll)) (err u104))
    (map-set polls
      { poll-id: poll-id }
      (merge poll { active: false })
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-poll (poll-id uint))
  (map-get? polls { poll-id: poll-id })
)

(define-read-only (get-total-polls)
  (var-get poll-count)
)

(define-read-only (has-voted (poll-id uint) (voter principal))
  (is-some (map-get? votes { poll-id: poll-id, voter: voter }))
)

(define-read-only (get-vote (poll-id uint) (voter principal))
  (map-get? votes { poll-id: poll-id, voter: voter })
)

(define-read-only (get-results (poll-id uint))
  (match (map-get? polls { poll-id: poll-id })
    poll (ok {
      question: (get question poll),
      option-a: (get option-a poll),
      option-b: (get option-b poll),
      votes-a: (get votes-a poll),
      votes-b: (get votes-b poll),
      total-votes: (+ (get votes-a poll) (get votes-b poll)),
      active: (get active poll),
      ended: (>= stacks-block-height (get end-block poll))
    })
    ERR-POLL-NOT-FOUND
  )
)