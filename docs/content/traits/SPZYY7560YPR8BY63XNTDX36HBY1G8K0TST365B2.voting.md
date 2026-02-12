---
title: "Trait voting"
draft: true
---
```
;; voting.clar
;; Simple voting and governance system

;; Constants
(define-constant ERR-PROPOSAL-NOT-FOUND (err u101))
(define-constant ERR-PROPOSAL-NOT-ACTIVE (err u103))
(define-constant ERR-PROPOSAL-STILL-ACTIVE (err u104))
(define-constant ERR-ALREADY-VOTED (err u105))
(define-constant ERR-EMPTY-TITLE (err u106))

;; Status
(define-constant STATUS-ACTIVE u0)
(define-constant STATUS-PASSED u1)
(define-constant STATUS-REJECTED u2)

;; Data Variables
(define-data-var proposal-counter uint u0)

;; Maps
(define-map proposals uint 
  {
    creator: principal,
    title: (string-ascii 64),
    description: (string-ascii 256),
    yes-votes: uint,
    no-votes: uint,
    created-at: uint,
    end-time: uint,
    quorum: uint,
    status: uint
  }
)

(define-map has-voted { proposal-id: uint, voter: principal } bool)

;; Public Functions
(define-public (create-proposal (title (string-ascii 64)) (description (string-ascii 256)) (duration-days uint) (quorum uint))
  (let (
    (proposal-id (+ (var-get proposal-counter) u1))
    (duration (if (> duration-days u0) (* duration-days u86400) u604800))
    (end-time (+ stacks-block-time duration))
  )
    (begin
      (asserts! (> (len title) u0) ERR-EMPTY-TITLE)
      (asserts! (> (len description) u0) (err u107))
      
      (map-set proposals proposal-id {
        creator: tx-sender,
        title: title,
        description: description,
        yes-votes: u0,
        no-votes: u0,
        created-at: stacks-block-time,
        end-time: end-time,
        quorum: (if (> quorum u0) quorum u10),
        status: STATUS-ACTIVE
      })
      
      (var-set proposal-counter proposal-id)
      (print { event: "proposal-created", id: proposal-id, creator: tx-sender, end-time: end-time })
      (ok proposal-id)
    )
  )
)

(define-public (vote (proposal-id uint) (support bool))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND)))
    (begin
      (asserts! (is-eq (get status proposal) STATUS-ACTIVE) ERR-PROPOSAL-NOT-ACTIVE)
      (asserts! (< stacks-block-time (get end-time proposal)) ERR-PROPOSAL-STILL-ACTIVE)
      (asserts! (is-none (map-get? has-voted { proposal-id: proposal-id, voter: tx-sender })) ERR-ALREADY-VOTED)
      
      (map-set has-voted { proposal-id: proposal-id, voter: tx-sender } true)
      
      (if support
        (map-set proposals proposal-id (merge proposal { yes-votes: (+ (get yes-votes proposal) u1) }))
        (map-set proposals proposal-id (merge proposal { no-votes: (+ (get no-votes proposal) u1) }))
      )
      
      (print { event: "vote-cast", id: proposal-id, voter: tx-sender, support: support })
      (ok true)
    )
  )
)

(define-public (finalize-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND)))
    (begin
      (asserts! (is-eq (get status proposal) STATUS-ACTIVE) ERR-PROPOSAL-NOT-ACTIVE)
      (asserts! (>= stacks-block-time (get end-time proposal)) ERR-PROPOSAL-STILL-ACTIVE)
      
      (let (
        (total-votes (+ (get yes-votes proposal) (get no-votes proposal)))
        (passed (and (>= total-votes (get quorum proposal)) (> (get yes-votes proposal) (get no-votes proposal))))
      )
        (begin
          (map-set proposals proposal-id (merge proposal { status: (if passed STATUS-PASSED STATUS-REJECTED) }))
          (print { event: "proposal-finalized", id: proposal-id, status: (if passed STATUS-PASSED STATUS-REJECTED) })
          (ok true)
        )
      )
    )
  )
)

;; Read-only
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

;; CLARITY 4 FEATURE: to-ascii? for proposal status
(define-read-only (get-proposal-status-ascii (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal (let (
      (votes-yes-ascii (match (to-ascii? (get yes-votes proposal)) ok-val ok-val err "0"))
      (votes-no-ascii (match (to-ascii? (get no-votes proposal)) ok-val ok-val err "0"))
      (status-val (get status proposal))
      (status-str (if (is-eq status-val STATUS-ACTIVE) "ACTIVE"
        (if (is-eq status-val STATUS-PASSED) "PASSED"
        (if (is-eq status-val STATUS-REJECTED) "REJECTED"
        "CANCELLED"))))
    )
      (ok {
        title: (get title proposal),
        yes-votes: votes-yes-ascii,
        no-votes: votes-no-ascii,
        status: status-str
      })
    )
    (ok {
        title: "Proposal not found",
        yes-votes: "0",
        no-votes: "0",
        status: "NOT_FOUND"
    })
  )
)

```
