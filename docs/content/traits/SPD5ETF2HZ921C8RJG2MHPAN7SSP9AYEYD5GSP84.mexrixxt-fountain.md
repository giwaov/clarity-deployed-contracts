---
title: "Trait mexrixxt-fountain"
draft: true
---
```
;;  Governance Rewards - Reward Distribution System (Clarity 4)
;; This contract manages reward distribution for governance participants

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u3001))
(define-constant ERR-NO-REWARDS (err u3002))
(define-constant ERR-ALREADY-CLAIMED (err u3003))
(define-constant ERR-INVALID-AMOUNT (err u3004))

;; Data variables
(define-data-var total-rewards-distributed uint u0)
(define-data-var reward-rate uint u100) ;; Rewards per vote in basis points

;; Data maps
(define-map user-rewards
    { user: principal }
    {
        earned: uint,
        claimed: uint,
        last-claim: uint,                   ;; Clarity 4: Unix timestamp
        pending: uint
    }
)

(define-map reward-claims
    { user: principal, claim-id: uint }
    {
        amount: uint,
        claimed-at: uint                    ;; Clarity 4: Unix timestamp
    }
)

(define-map claim-count { user: principal } uint)

;; Read-only functions
(define-read-only (get-user-rewards (user principal))
    (ok (map-get? user-rewards { user: user }))
)

(define-read-only (get-pending-rewards (user principal))
    (match (map-get? user-rewards { user: user })
        rewards (ok (get pending rewards))
        (ok u0)
    )
)

(define-read-only (get-total-earned (user principal))
    (match (map-get? user-rewards { user: user })
        rewards (ok (get earned rewards))
        (ok u0)
    )
)

;; Public functions
(define-public (record-activity (user principal) (activity-type (string-ascii 20)) (reward-amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

        (match (map-get? user-rewards { user: user })
            existing-rewards
                (map-set user-rewards
                    { user: user }
                    {
                        earned: (+ (get earned existing-rewards) reward-amount),
                        claimed: (get claimed existing-rewards),
                        last-claim: (get last-claim existing-rewards),
                        pending: (+ (get pending existing-rewards) reward-amount)
                    }
                )
            (map-set user-rewards
                { user: user }
                {
                    earned: reward-amount,
                    claimed: u0,
                    last-claim: u0,
                    pending: reward-amount
                }
            )
        )

        (print {
            event: "reward-recorded",
            user: user,
            activity-type: activity-type,
            amount: reward-amount,
            timestamp: stacks-block-time
        })
        (ok true)
    )
)

(define-public (claim-rewards)
    (let
        (
            (rewards (unwrap! (map-get? user-rewards { user: tx-sender }) ERR-NO-REWARDS))
            (pending (get pending rewards))
            (claim-id (default-to u0 (map-get? claim-count { user: tx-sender })))
        )
        (asserts! (> pending u0) ERR-NO-REWARDS)

        (map-set user-rewards
            { user: tx-sender }
            (merge rewards {
                claimed: (+ (get claimed rewards) pending),
                last-claim: stacks-block-time,
                pending: u0
            })
        )

        (map-set reward-claims
            { user: tx-sender, claim-id: claim-id }
            {
                amount: pending,
                claimed-at: stacks-block-time
            }
        )

        (map-set claim-count { user: tx-sender } (+ claim-id u1))
        (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) pending))

        (print {
            event: "rewards-claimed",
            user: tx-sender,
            amount: pending,
            timestamp: stacks-block-time
        })
        (ok pending)
    )
)

(define-public (set-reward-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set reward-rate new-rate)
        (ok true)
    )
)

```
