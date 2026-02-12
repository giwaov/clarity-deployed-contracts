---
title: "Trait crowdfunding-campaign"
draft: true
---
```
;; crowdfunding-campaign.clar
;; Crowdfunding system with goals, deadlines, and refunds

;; Constants
(define-constant CONTRACT-ADDRESS .crowdfunding-campaign)
(define-constant ERR-CAMPAIGN-NOT-FOUND (err u100))
(define-constant ERR-NOT-CREATOR (err u101))
(define-constant ERR-CAMPAIGN-NOT-ACTIVE (err u102))
(define-constant ERR-CAMPAIGN-STILL-ACTIVE (err u103))
(define-constant ERR-INVALID-GOAL (err u104))
(define-constant ERR-ZERO-CONTRIBUTION (err u105))
(define-constant ERR-CAMPAIGN-NOT-FAILED (err u106))
(define-constant ERR-NO-CONTRIBUTION (err u107))
(define-constant ERR-FUNDS-ALREADY-WITHDRAWN (err u108))
(define-constant ERR-CAMPAIGN-NOT-SUCCESSFUL (err u109))

;; Status
(define-constant STATUS-ACTIVE u0)
(define-constant STATUS-SUCCESSFUL u1)
(define-constant STATUS-FAILED u2)

;; Data Variables
(define-data-var campaign-counter uint u0)

;; Maps
(define-map campaigns uint 
  {
    creator: principal,
    title: (string-ascii 64),
    description: (string-ascii 256),
    goal: uint,
    raised: uint,
    deadline: uint,
    status: uint,
    funds-withdrawn: bool,
    contributor-count: uint
  }
)

(define-map user-contributions { campaign-id: uint, user: principal } uint)

;; Public Functions
(define-public (create-campaign (title (string-ascii 64)) (description (string-ascii 256)) (goal uint) (duration-days uint))
  (let (
    (campaign-id (+ (var-get campaign-counter) u1))
    (deadline (+ stacks-block-time (* duration-days u86400)))
  )
    (begin
      (asserts! (> (len title) u0) (err u110))
      (asserts! (> (len description) u0) (err u111))
      (asserts! (> goal u0) ERR-INVALID-GOAL)
      (asserts! (> duration-days u0) ERR-CAMPAIGN-STILL-ACTIVE)
      
      (map-set campaigns campaign-id {
        creator: tx-sender,
        title: title,
        description: description,
        goal: goal,
        raised: u0,
        deadline: deadline,
        status: STATUS-ACTIVE,
        funds-withdrawn: false,
        contributor-count: u0
      })
      
      (var-set campaign-counter campaign-id)
      (print { event: "campaign-created", id: campaign-id, creator: tx-sender, goal: goal, deadline: deadline })
      (ok campaign-id)
    )
  )
)

(define-public (contribute (campaign-id uint) (amount uint))
  (let (
    (campaign (unwrap! (map-get? campaigns campaign-id) ERR-CAMPAIGN-NOT-FOUND))
    (current-contribution (default-to u0 (map-get? user-contributions { campaign-id: campaign-id, user: tx-sender })))
  )
    (begin
      (asserts! (> amount u0) ERR-ZERO-CONTRIBUTION)
      (asserts! (is-eq (get status campaign) STATUS-ACTIVE) ERR-CAMPAIGN-NOT-ACTIVE)
      (asserts! (< stacks-block-time (get deadline campaign)) ERR-CAMPAIGN-STILL-ACTIVE)
      
      (unwrap-panic (stx-transfer? amount tx-sender CONTRACT-ADDRESS))
      
      (let ((new-raised (+ (get raised campaign) amount)))
        (begin
          (map-set user-contributions { campaign-id: campaign-id, user: tx-sender } (+ current-contribution amount))
          (map-set campaigns campaign-id (merge campaign {
            raised: new-raised,
            contributor-count: (if (is-eq current-contribution u0) (+ (get contributor-count campaign) u1) (get contributor-count campaign)),
            status: (if (>= new-raised (get goal campaign)) STATUS-SUCCESSFUL (get status campaign))
          }))
          (print { event: "contribution-made", id: campaign-id, contributor: tx-sender, amount: amount })
          (ok true)
        )
      )
    )
  )
)

(define-public (withdraw-funds (campaign-id uint))
  (let ((campaign (unwrap! (map-get? campaigns campaign-id) ERR-CAMPAIGN-NOT-FOUND)))
    (begin
      (asserts! (is-eq (get status campaign) STATUS-SUCCESSFUL) ERR-CAMPAIGN-NOT-SUCCESSFUL)
      (asserts! (not (get funds-withdrawn campaign)) ERR-FUNDS-ALREADY-WITHDRAWN)
      
      (let ((amount (get raised campaign)))
        (begin
          (map-set campaigns campaign-id (merge campaign { funds-withdrawn: true }))
          (try! (stx-transfer? amount CONTRACT-ADDRESS (get creator campaign)))
          (print { event: "funds-withdrawn", id: campaign-id, creator: (get creator campaign), amount: amount })
          (ok true)
        )
      )
    )
  )
)

(define-public (claim-refund (campaign-id uint))
  (let (
    (campaign (unwrap! (map-get? campaigns campaign-id) ERR-CAMPAIGN-NOT-FOUND))
    (contribution (unwrap! (map-get? user-contributions { campaign-id: campaign-id, user: tx-sender }) ERR-NO-CONTRIBUTION))
  )
    (begin
      ;; Check if failed or expired and not reached goal
      (asserts! (or 
                  (is-eq (get status campaign) STATUS-FAILED)
                  (and (is-eq (get status campaign) STATUS-ACTIVE) (>= stacks-block-time (get deadline campaign)) (< (get raised campaign) (get goal campaign)))) 
                ERR-CAMPAIGN-NOT-FAILED)
      
      (map-delete user-contributions { campaign-id: campaign-id, user: tx-sender })
      (try! (stx-transfer? contribution CONTRACT-ADDRESS tx-sender))
      (print { event: "refund-claimed", id: campaign-id, contributor: tx-sender, amount: contribution })
      (ok true)
    )
  )
)

;; Read-only
(define-read-only (get-campaign (campaign-id uint))
  (map-get? campaigns campaign-id)
)

;; CLARITY 4 FEATURE: to-ascii? for campaign status
(define-read-only (get-campaign-status-ascii (campaign-id uint))
  (match (map-get? campaigns campaign-id)
    campaign (let (
      (raised-ascii (match (to-ascii? (get raised campaign)) ok-val ok-val err "0"))
      (goal-ascii (match (to-ascii? (get goal campaign)) ok-val ok-val err "0"))
      (status-val (get status campaign))
      (status-str (if (is-eq status-val STATUS-ACTIVE) "ACTIVE"
        (if (is-eq status-val STATUS-SUCCESSFUL) "SUCCESSFUL"
        (if (is-eq status-val STATUS-FAILED) "FAILED"
        "CANCELLED"))))
    )
      (ok {
        title: (get title campaign),
        raised: raised-ascii,
        goal: goal-ascii,
        status: status-str
      })
    )
    (ok {
        title: "Campaign not found",
        raised: "0",
        goal: "0",
        status: "NOT_FOUND"
    })
  )
)

```
