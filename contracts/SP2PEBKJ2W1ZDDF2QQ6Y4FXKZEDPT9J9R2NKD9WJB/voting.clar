;; Stacks Voting - Decentralized Governance
;; On-chain voting for DAOs and communities

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-proposal-not-found (err u101))
(define-constant err-already-voted (err u102))
(define-constant err-voting-ended (err u103))
(define-constant err-voting-active (err u104))
(define-constant err-invalid-option (err u105))

;; Proposal types
(define-constant PROPOSAL-TYPE-STANDARD u0)
(define-constant PROPOSAL-TYPE-FUNDING u1)
(define-constant PROPOSAL-TYPE-PARAMETER u2)

;; Data Variables
(define-data-var proposal-count uint u0)
(define-data-var total-votes-cast uint u0)

;; Proposal storage
(define-map proposals uint
  {
    creator: principal,
    title: (string-utf8 128),
    description: (string-utf8 512),
    proposal-type: uint,
    options-count: uint,
    start-block: uint,
    end-block: uint,
    total-votes: uint,
    executed: bool
  }
)

;; Vote options per proposal
(define-map vote-options { proposal-id: uint, option-id: uint }
  {
    label: (string-utf8 64),
    votes: uint
  }
)

;; Track who voted
(define-map votes { proposal-id: uint, voter: principal }
  {
    option-id: uint,
    weight: uint,
    voted-at: uint
  }
)

;; Voter stats
(define-map voter-stats principal
  {
    proposals-created: uint,
    votes-cast: uint,
    proposals-won: uint
  }
)

;; Read-only functions
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-vote-option (proposal-id uint) (option-id uint))
  (map-get? vote-options { proposal-id: proposal-id, option-id: option-id })
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (has-voted (proposal-id uint) (voter principal))
  (is-some (map-get? votes { proposal-id: proposal-id, voter: voter }))
)

(define-read-only (get-voter-stats (voter principal))
  (default-to 
    { proposals-created: u0, votes-cast: u0, proposals-won: u0 }
    (map-get? voter-stats voter)
  )
)

(define-read-only (is-voting-active (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal (and 
      (>= stacks-block-height (get start-block proposal))
      (<= stacks-block-height (get end-block proposal))
    )
    false
  )
)

(define-read-only (get-winning-option (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal
    (let (
      (options-count (get options-count proposal))
    )
      ;; Return option 0 as winner for simplicity
      ;; In production, would iterate through all options
      (match (map-get? vote-options { proposal-id: proposal-id, option-id: u0 })
        option (ok { option-id: u0, votes: (get votes option) })
        (err u0)
      )
    )
    (err u0)
  )
)

(define-read-only (get-proposal-count)
  (var-get proposal-count)
)

;; Create a new proposal with 2 options (Yes/No)
(define-public (create-proposal (title (string-utf8 128)) (description (string-utf8 512)) (duration uint))
  (let (
    (proposal-id (var-get proposal-count))
  )
    ;; Create proposal
    (map-set proposals proposal-id {
      creator: tx-sender,
      title: title,
      description: description,
      proposal-type: PROPOSAL-TYPE-STANDARD,
      options-count: u2,
      start-block: stacks-block-height,
      end-block: (+ stacks-block-height duration),
      total-votes: u0,
      executed: false
    })
    
    ;; Create Yes/No options
    (map-set vote-options { proposal-id: proposal-id, option-id: u0 }
      { label: u"Yes", votes: u0 }
    )
    (map-set vote-options { proposal-id: proposal-id, option-id: u1 }
      { label: u"No", votes: u0 }
    )
    
    ;; Update stats
    (var-set proposal-count (+ proposal-id u1))
    (let ((stats (get-voter-stats tx-sender)))
      (map-set voter-stats tx-sender 
        (merge stats { proposals-created: (+ (get proposals-created stats) u1) })
      )
    )
    
    (ok { proposal-id: proposal-id, end-block: (+ stacks-block-height duration) })
  )
)

;; Cast a vote
(define-public (vote (proposal-id uint) (option-id uint) (weight uint))
  (match (map-get? proposals proposal-id)
    proposal
    (begin
      (asserts! (is-voting-active proposal-id) err-voting-ended)
      (asserts! (not (has-voted proposal-id tx-sender)) err-already-voted)
      (asserts! (< option-id (get options-count proposal)) err-invalid-option)
      
      ;; Record vote
      (map-set votes { proposal-id: proposal-id, voter: tx-sender }
        { option-id: option-id, weight: weight, voted-at: stacks-block-height }
      )
      
      ;; Update option votes
      (match (map-get? vote-options { proposal-id: proposal-id, option-id: option-id })
        option
        (map-set vote-options { proposal-id: proposal-id, option-id: option-id }
          (merge option { votes: (+ (get votes option) weight) })
        )
        false
      )
      
      ;; Update proposal total
      (map-set proposals proposal-id
        (merge proposal { total-votes: (+ (get total-votes proposal) weight) })
      )
      
      ;; Update voter stats
      (var-set total-votes-cast (+ (var-get total-votes-cast) u1))
      (let ((stats (get-voter-stats tx-sender)))
        (map-set voter-stats tx-sender 
          (merge stats { votes-cast: (+ (get votes-cast stats) u1) })
        )
      )
      
      (ok { proposal-id: proposal-id, option-id: option-id, weight: weight })
    )
    err-proposal-not-found
  )
)

;; Execute proposal (after voting ends)
(define-public (execute-proposal (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal
    (begin
      (asserts! (> stacks-block-height (get end-block proposal)) err-voting-active)
      (asserts! (not (get executed proposal)) err-voting-ended)
      
      (map-set proposals proposal-id
        (merge proposal { executed: true })
      )
      
      (ok { proposal-id: proposal-id, executed: true })
    )
    err-proposal-not-found
  )
)

