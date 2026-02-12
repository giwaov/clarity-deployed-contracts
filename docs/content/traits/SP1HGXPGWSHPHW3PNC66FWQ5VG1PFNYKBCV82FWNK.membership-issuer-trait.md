---
title: "Trait membership-issuer-trait"
draft: true
---
```
;; MembershipIssuerTrait
;; Defines the interface for creating and managing memberships
;; Implementers can issue, renew, and cancel memberships

(define-trait membership-issuer-trait
  (
    ;; Issue a new membership to a principal
    ;; Returns membership ID on success
    (issue-membership (principal uint uint) (response uint uint))

    ;; Renew an existing membership
    ;; Extends the expiration time
    (renew-membership (principal uint) (response bool uint))

    ;; Cancel a membership before expiration
    ;; Maintains record of cancellation
    (cancel-membership (principal uint) (response bool uint))

    ;; Update membership tier
    ;; Allows tier upgrades/downgrades
    (update-membership-tier (principal uint uint) (response bool uint))

    ;; Transfer membership to another principal
    ;; Maintains ownership chain
    (transfer-membership (principal principal uint) (response bool uint))

    ;; Get total memberships issued by this issuer
    (get-total-memberships () (response uint uint))

    ;; Check if a principal holds a valid membership
    (is-member (principal) (response bool uint))

    ;; Get membership expiration timestamp
    (get-membership-expiration (principal) (response uint uint))
  )
)

```
