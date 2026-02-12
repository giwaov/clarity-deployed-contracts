---
title: "Trait subscription-trait"
draft: true
---
```
;; SubscriptionTrait
;; Defines the interface for recurring subscription management
;; Handles automatic renewals, billing cycles, and subscription lifecycle

(define-trait subscription-trait
  (
    ;; Create a new subscription plan
    ;; Defines frequency, amount, and duration
    (create-subscription-plan (uint uint uint) (response uint uint))

    ;; Subscribe a principal to a plan
    ;; Sets up automatic renewal schedule
    (subscribe-to-plan (principal uint) (response uint uint))

    ;; Process recurring payment for a subscription
    ;; Called by automation or user action
    (process-subscription-payment (principal uint) (response bool uint))

    ;; Pause a subscription temporarily
    ;; Resumes at specified block height
    (pause-subscription (principal uint uint) (response bool uint))

    ;; Resume a paused subscription
    (resume-subscription (principal uint) (response bool uint))

    ;; Cancel subscription and stop recurring payments
    (cancel-subscription (principal uint) (response bool uint))

    ;; Get next payment due date for a subscription
    (get-next-payment-due (principal) (response uint uint))

    ;; Get subscription payment history
    ;; Returns count of successful payments
    (get-payment-count (principal) (response uint uint))

    ;; Check if subscription is active
    (is-subscription-active (principal) (response bool uint))

    ;; Update subscription plan pricing
    ;; Changes future billing amounts
    (update-plan-price (uint uint) (response bool uint))
  )
)

```
