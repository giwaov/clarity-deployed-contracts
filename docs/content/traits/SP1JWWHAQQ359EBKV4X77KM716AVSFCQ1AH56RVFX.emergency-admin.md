---
title: "Trait emergency-admin"
draft: true
---
```
;; title: emergency-admin
;; version:
;; summary:
;; description:

;; Subscription Service Contract

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INSUFFICIENT-BALANCE (err u103))
(define-constant ERR-EXPIRED (err u104))
(define-constant ERR-INVALID-INPUT (err u105))

;; Data maps
(define-map subscription-plans
  { plan-id: uint }
  {
    plan-name: (string-ascii 50),
    subscription-duration: uint,
    plan-price: uint,
  }
)

(define-map user-subscriptions
  { subscriber: principal }
  {
    subscribed-plan-id: uint,
    subscription-start-block: uint,
    subscription-end-block: uint,
  }
)

;; Variables
(define-data-var next-available-plan-id uint u1)

;; Read-only functions
(define-read-only (get-subscription-plan (plan-id uint))
  (map-get? subscription-plans { plan-id: plan-id })
)

(define-read-only (get-user-subscription-details (subscriber principal))
  (map-get? user-subscriptions { subscriber: subscriber })
)

(define-read-only (is-subscription-active (subscriber principal))
  (match (get-user-subscription-details subscriber)
    subscription-details (> (get subscription-end-block subscription-details) stacks-block-height)
    false
  )
)

;; Private functions
(define-private (transfer-stx-tokens
    (amount uint)
    (sender principal)
    (recipient principal)
  )
  (match (stx-transfer? amount sender recipient)
    transfer-success (ok true)
    transfer-error (err transfer-error)
  )
)

(define-private (validate-plan-input
    (plan-name (string-ascii 50))
    (subscription-duration uint)
    (plan-price uint)
  )
  (and
    (> (len plan-name) u0)
    (< (len plan-name) u51)
    (> subscription-duration u0)
    (> plan-price u0)
  )
)

;; Public functions
(define-public (add-subscription-plan
    (plan-name (string-ascii 50))
    (subscription-duration uint)
    (plan-price uint)
  )
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (validate-plan-input plan-name subscription-duration plan-price)
      ERR-INVALID-INPUT
    )
    (let ((new-plan-id (var-get next-available-plan-id)))
      (asserts! (is-none (get-subscription-plan new-plan-id)) ERR-ALREADY-EXISTS)
      (map-set subscription-plans { plan-id: new-plan-id } {
        plan-name: plan-name,
        subscription-duration: subscription-duration,
        plan-price: plan-price,
      })
      (var-set next-available-plan-id (+ new-plan-id u1))
      (ok new-plan-id)
    )
  )
)

(define-public (update-subscription-plan
    (plan-id uint)
    (plan-name (string-ascii 50))
    (subscription-duration uint)
    (plan-price uint)
  )
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (validate-plan-input plan-name subscription-duration plan-price)
      ERR-INVALID-INPUT
    )
    (asserts! (is-some (get-subscription-plan plan-id)) ERR-NOT-FOUND)
    (map-set subscription-plans { plan-id: plan-id } {
      plan-name: plan-name,
      subscription-duration: subscription-duration,
      plan-price: plan-price,
    })
    (ok true)
  )
)

(define-public (delete-subscription-plan (plan-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (is-some (get-subscription-plan plan-id)) ERR-NOT-FOUND)
    (map-delete subscription-plans { plan-id: plan-id })
    (ok true)
  )
)

(define-public (cancel-user-subscription)
  (begin
    (asserts! (is-some (get-user-subscription-details tx-sender)) ERR-NOT-FOUND)
    (map-delete user-subscriptions { subscriber: tx-sender })
    (ok true)
  )
)

```
