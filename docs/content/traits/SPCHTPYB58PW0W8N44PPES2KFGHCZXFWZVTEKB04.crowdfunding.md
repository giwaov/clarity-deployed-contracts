---
title: "Trait crowdfunding"
draft: true
---
```
;; Crowdfunding Contract
;; Create campaigns and collect STX until goal is met

(define-constant err-not-owner (err u100))
(define-constant err-campaign-not-found (err u101))
(define-constant err-campaign-ended (err u102))
(define-constant err-goal-not-met (err u103))
(define-constant err-goal-already-met (err u104))
(define-constant err-no-contribution (err u105))

(define-data-var campaign-nonce uint u0)

(define-map campaigns
    uint
    {
        owner: principal,
        title: (string-ascii 50),
        description: (string-ascii 500),
        goal: uint,
        raised: uint,
        deadline: uint,
        claimed: bool
    }
)

(define-map contributions {campaign-id: uint, contributor: principal} uint)

;; Create a new campaign
(define-public (create-campaign (title (string-ascii 50)) (description (string-ascii 500)) (goal uint) (duration uint))
    (let
        (
            (campaign-id (var-get campaign-nonce))
        )
        (map-set campaigns campaign-id {
            owner: tx-sender,
            title: title,
            description: description,
            goal: goal,
            raised: u0,
            deadline: (+ block-height duration),
            claimed: false
        })
        (var-set campaign-nonce (+ campaign-id u1))
        (ok campaign-id)
    )
)

;; Contribute to a campaign
(define-public (contribute (campaign-id uint) (amount uint))
    (let
        (
            (campaign (unwrap! (map-get? campaigns campaign-id) err-campaign-not-found))
            (contribution-key {campaign-id: campaign-id, contributor: tx-sender})
            (existing-contribution (default-to u0 (map-get? contributions contribution-key)))
        )
        (asserts! (< block-height (get deadline campaign)) err-campaign-ended)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set contributions contribution-key (+ existing-contribution amount))
        (map-set campaigns campaign-id (merge campaign {raised: (+ (get raised campaign) amount)}))
        (ok true)
    )
)

;; Claim funds if goal is met
(define-public (claim-funds (campaign-id uint))
    (let
        (
            (campaign (unwrap! (map-get? campaigns campaign-id) err-campaign-not-found))
        )
        (asserts! (is-eq tx-sender (get owner campaign)) err-not-owner)
        (asserts! (>= (get raised campaign) (get goal campaign)) err-goal-not-met)
        (asserts! (not (get claimed campaign)) err-goal-already-met)
        (try! (as-contract (stx-transfer? (get raised campaign) tx-sender (get owner campaign))))
        (map-set campaigns campaign-id (merge campaign {claimed: true}))
        (ok true)
    )
)

;; Refund if campaign failed
(define-public (refund (campaign-id uint))
    (let
        (
            (campaign (unwrap! (map-get? campaigns campaign-id) err-campaign-not-found))
            (contribution-key {campaign-id: campaign-id, contributor: tx-sender})
            (contribution (unwrap! (map-get? contributions contribution-key) err-no-contribution))
        )
        (asserts! (>= block-height (get deadline campaign)) err-campaign-ended)
        (asserts! (< (get raised campaign) (get goal campaign)) err-goal-already-met)
        (try! (as-contract (stx-transfer? contribution tx-sender tx-sender)))
        (map-delete contributions contribution-key)
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-campaign (campaign-id uint))
    (map-get? campaigns campaign-id)
)

(define-read-only (get-contribution (campaign-id uint) (contributor principal))
    (default-to u0 (map-get? contributions {campaign-id: campaign-id, contributor: contributor}))
)

```
