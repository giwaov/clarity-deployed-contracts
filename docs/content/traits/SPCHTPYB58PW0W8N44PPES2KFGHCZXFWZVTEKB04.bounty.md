---
title: "Trait bounty"
draft: true
---
```
;; Bounty Contract
;; Post bounties and submit work for rewards

(define-constant err-not-found (err u100))
(define-constant err-already-claimed (err u101))
(define-constant err-not-authorized (err u102))
(define-constant err-bounty-closed (err u103))

(define-data-var bounty-nonce uint u0)
(define-data-var submission-nonce uint u0)

(define-map bounties
    uint
    {
        creator: principal,
        title: (string-utf8 100),
        description: (string-utf8 1000),
        reward: uint,
        deadline: uint,
        claimed: bool,
        winner: (optional principal)
    }
)

(define-map submissions
    uint
    {
        bounty-id: uint,
        submitter: principal,
        submission-url: (string-utf8 200),
        timestamp: uint,
        accepted: bool
    }
)

(define-public (create-bounty
    (title (string-utf8 100))
    (description (string-utf8 1000))
    (reward uint)
    (deadline uint))
    (let ((bounty-id (var-get bounty-nonce)))
        (try! (stx-transfer? reward tx-sender (as-contract tx-sender)))
        (map-set bounties bounty-id {
            creator: tx-sender,
            title: title,
            description: description,
            reward: reward,
            deadline: deadline,
            claimed: false,
            winner: none
        })
        (var-set bounty-nonce (+ bounty-id u1))
        (ok bounty-id)
    )
)

(define-public (submit-work (bounty-id uint) (submission-url (string-utf8 200)))
    (let
        (
            (bounty (unwrap! (map-get? bounties bounty-id) err-not-found))
            (submission-id (var-get submission-nonce))
        )
        (asserts! (not (get claimed bounty)) err-already-claimed)
        (asserts! (< block-height (get deadline bounty)) err-bounty-closed)
        
        (map-set submissions submission-id {
            bounty-id: bounty-id,
            submitter: tx-sender,
            submission-url: submission-url,
            timestamp: block-height,
            accepted: false
        })
        (var-set submission-nonce (+ submission-id u1))
        (ok submission-id)
    )
)

(define-public (accept-submission (submission-id uint))
    (let
        (
            (submission (unwrap! (map-get? submissions submission-id) err-not-found))
            (bounty (unwrap! (map-get? bounties (get bounty-id submission)) err-not-found))
        )
        (asserts! (is-eq tx-sender (get creator bounty)) err-not-authorized)
        (asserts! (not (get claimed bounty)) err-already-claimed)
        
        (try! (as-contract (stx-transfer? (get reward bounty) tx-sender (get submitter submission))))
        
        (map-set bounties (get bounty-id submission) (merge bounty {
            claimed: true,
            winner: (some (get submitter submission))
        }))
        (map-set submissions submission-id (merge submission {accepted: true}))
        (ok true)
    )
)

(define-public (cancel-bounty (bounty-id uint))
    (let ((bounty (unwrap! (map-get? bounties bounty-id) err-not-found)))
        (asserts! (is-eq tx-sender (get creator bounty)) err-not-authorized)
        (asserts! (not (get claimed bounty)) err-already-claimed)
        (try! (as-contract (stx-transfer? (get reward bounty) tx-sender (get creator bounty))))
        (map-delete bounties bounty-id)
        (ok true)
    )
)

(define-read-only (get-bounty (bounty-id uint))
    (map-get? bounties bounty-id)
)

(define-read-only (get-submission (submission-id uint))
    (map-get? submissions submission-id)
)

```
