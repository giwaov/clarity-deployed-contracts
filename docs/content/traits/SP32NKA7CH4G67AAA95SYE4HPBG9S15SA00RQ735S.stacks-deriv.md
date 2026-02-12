---
title: "Trait stacks-deriv"
draft: true
---
```
;; Academic Research Funding Smart Contract

;; Define constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u102))
(define-constant ERR_INSUFFICIENT_FUNDS (err u103))
(define-constant ERR_INVALID_STATUS (err u104))
(define-constant ERR_DEADLINE_PASSED (err u105))
(define-constant ERR_INVALID_REVIEW (err u106))
(define-constant ERR_ALREADY_REVIEWED (err u107))
(define-constant ERR_NOT_ENOUGH_REVIEWS (err u108))
(define-constant ERR_INVALID_DEADLINE (err u109))
(define-constant ERR_INVALID_MILESTONES (err u110))
(define-constant ERR_INSUFFICIENT_REPUTATION (err u111))
(define-constant ERR_ACTIVE_PROPOSAL_EXISTS (err u112))
(define-constant ERR_EVENT_EMISSION_FAILED (err u113))
(define-constant ERR_INVALID_MILESTONE_INDEX (err u114))
(define-constant ERR_MAP_UPDATE_FAILED (err u115))
(define-constant MAX_EVENT_LENGTH u500)
(define-constant MAX_DESCRIPTION_LENGTH u500)
(define-constant ERR_INVALID_MILESTONE (err u116))

;; Define data maps
(define-map Proposals
  { proposal-id: uint }
  {
    researcher: principal,
    title: (string-ascii 100),
    description: (string-utf8 1000),
    requested-amount: uint,
    status: (string-ascii 20),
    funded-amount: uint,
    milestones: (list 5 (string-ascii 100)),
    deadline: uint,
    review-count: uint,
    average-rating: uint,
    escrow-amount: uint,
  }
)

(define-map ResearcherBalance
  principal
  uint
)
(define-map ResearcherReputation
  principal
  uint
)
(define-map Reviews
  {
    proposal-id: uint,
    reviewer: principal,
  }
  {
    rating: uint,
    comment: (string-utf8 500),
  }
)
(define-map Votes
  {
    proposal-id: uint,
    voter: principal,
  }
  uint
)
(define-map ActiveResearcherProposals
  principal
  uint
)

(define-map Events
  { event-id: uint }
  {
    event-type: (string-ascii 20),
    proposal-id: uint,
    data: (string-utf8 500),
  }
)

;; Define variables
(define-data-var proposal-count uint u0)
(define-data-var total-funds uint u0)
(define-data-var min-reputation-for-proposal uint u10)
(define-data-var last-event-id uint u0)

;; Helper function
(define-private (update-proposal
    (proposal-id uint)
    (proposal {
      researcher: principal,
      title: (string-ascii 100),
      description: (string-utf8 1000),
      requested-amount: uint,
      status: (string-ascii 20),
      funded-amount: uint,
      milestones: (list 5 (string-ascii 100)),
      deadline: uint,
      review-count: uint,
      average-rating: uint,
      escrow-amount: uint,
    })
  )
  (if (map-set Proposals { proposal-id: proposal-id } proposal)
    (ok true)
    (err ERR_MAP_UPDATE_FAILED)
  )
)

(define-private (update-milestone-at-index
    (milestones (list 5 (string-ascii 100)))
    (index uint)
    (new-milestone (string-ascii 100))
  )
  (let ((len (len milestones)))
    (asserts! (< index len) ERR_INVALID_MILESTONE_INDEX)
    (ok (get result
      (fold update-milestone-fold milestones {
        current-index: u0,
        target-index: index,
        new-milestone: new-milestone,
        result: (list),
      })
    ))
  )
)

(define-private (update-milestone-fold
    (milestone (string-ascii 100))
    (state {
      current-index: uint,
      target-index: uint,
      new-milestone: (string-ascii 100),
      result: (list 5 (string-ascii 100)),
    })
  )
  (let ((updated-result (unwrap-panic (as-max-len?
      (append (get result state)
        (if (is-eq (get current-index state) (get target-index state))
          (get new-milestone state)
          milestone
        ))
      u5
    ))))
    (merge state {
      current-index: (+ (get current-index state) u1),
      result: updated-result,
    })
  )
)

;; Private functions

(define-private (emit-event
    (event-type (string-ascii 20))
    (proposal-id uint)
    (data (string-utf8 500))
  )
  (let (
      (event-id (+ (var-get last-event-id) u1))
      (truncated-data (unwrap-panic (as-max-len? data u500)))
    )
    (if (map-set Events { event-id: event-id } {
        event-type: event-type,
        proposal-id: proposal-id,
        data: truncated-data,
      })
      (begin
        (var-set last-event-id event-id)
        (ok event-id)
      )
      (err ERR_EVENT_EMISSION_FAILED)
    )
  )
)

;; Public functions

(define-public (submit-proposal
    (title (string-ascii 100))
    (description (string-utf8 1000))
    (requested-amount uint)
    (milestones (list 5 (string-ascii 100)))
    (deadline uint)
  )
  (let (
      (proposal-id (+ (var-get proposal-count) u1))
      (researcher-reputation (default-to u0 (map-get? ResearcherReputation tx-sender)))
      (truncated-description (unwrap-panic (as-max-len? description u500)))
    )
    (asserts! (> requested-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> deadline stacks-block-height) ERR_INVALID_DEADLINE)
    (asserts! (> (len milestones) u0) ERR_INVALID_MILESTONES)
    (asserts! (>= researcher-reputation (var-get min-reputation-for-proposal))
      ERR_INSUFFICIENT_REPUTATION
    )
    (asserts! (is-none (map-get? ActiveResearcherProposals tx-sender))
      ERR_ACTIVE_PROPOSAL_EXISTS
    )

    (match (update-proposal proposal-id {
      researcher: tx-sender,
      title: title,
      description: description,
      requested-amount: requested-amount,
      status: "pending",
      funded-amount: u0,
      milestones: milestones,
      deadline: deadline,
      review-count: u0,
      average-rating: u0,
      escrow-amount: u0,
    })
      update-success (begin
        (var-set proposal-count proposal-id)
        (map-set ActiveResearcherProposals tx-sender proposal-id)
        (match (emit-event "proposal-submitted" proposal-id truncated-description)
          emit-success (ok proposal-id)
          emit-error emit-error
        )
      )
      update-error update-error
    )
  )
)

;; Public functions

(define-public (approve-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? Proposals { proposal-id: proposal-id })
      (err ERR_PROPOSAL_NOT_FOUND)
    )))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_NOT_AUTHORIZED))
    (asserts! (is-eq (get status proposal) "pending") (err ERR_INVALID_STATUS))
    (match (update-proposal proposal-id (merge proposal { status: "approved" }))
      update-success (match (emit-event "proposal-approved" proposal-id u"Proposal approved")
        emit-success (ok true)
        emit-error (err ERR_EVENT_EMISSION_FAILED)
      )
      update-error (err ERR_MAP_UPDATE_FAILED)
    )
  )
)

(define-public (submit-review
    (proposal-id uint)
    (rating uint)
    (comment (string-utf8 500))
  )
  (let (
      (proposal (unwrap! (map-get? Proposals { proposal-id: proposal-id })
        (err ERR_PROPOSAL_NOT_FOUND)
      ))
      (existing-review (map-get? Reviews {
        proposal-id: proposal-id,
        reviewer: tx-sender,
      }))
    )
    (asserts! (and (>= rating u1) (<= rating u5)) (err ERR_INVALID_REVIEW))
    (asserts! (is-none existing-review) (err ERR_ALREADY_REVIEWED))
    (if (map-set Reviews {
        proposal-id: proposal-id,
        reviewer: tx-sender,
      } {
        rating: rating,
        comment: comment,
      })
      (let (
          (new-review-count (+ (get review-count proposal) u1))
          (new-average-rating (/
            (+ (* (get average-rating proposal) (get review-count proposal))
              rating
            )
            new-review-count
          ))
        )
        (if (map-set Proposals { proposal-id: proposal-id }
            (merge proposal {
              review-count: new-review-count,
              average-rating: new-average-rating,
            })
          )
          (match (emit-event "review-submitted" proposal-id comment)
            success (ok true)
            error (err ERR_EVENT_EMISSION_FAILED)
          )
          (err ERR_MAP_UPDATE_FAILED)
        )
      )
      (err ERR_MAP_UPDATE_FAILED)
    )
  )
)

(define-public (set-min-reputation (new-min-reputation uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set min-reputation-for-proposal new-min-reputation)
    (ok true)
  )
)

```
