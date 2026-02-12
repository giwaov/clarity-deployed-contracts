---
title: "Trait decentralized-job-board"
draft: true
---
```
;; Decentralized Job Board - Clarity 4
;; Post jobs and apply with escrow

(define-constant contract-owner tx-sender)
(define-constant err-not-found (err u3000))
(define-constant err-unauthorized (err u3001))
(define-constant err-already-filled (err u3002))

(define-data-var job-nonce uint u0)
(define-data-var platform-fee uint u250) ;; 2.5%

(define-map jobs
    uint
    {
        employer: principal,
        title: (string-utf8 100),
        description: (string-utf8 500),
        budget: uint,
        deadline: uint,
        filled: bool,
        worker: (optional principal),
        completed: bool
    }
)

(define-map applications
    {job-id: uint, applicant: principal}
    {proposal: (string-utf8 300), applied-at: uint}
)

(define-read-only (get-job (job-id uint))
    (map-get? jobs job-id)
)

(define-public (post-job
    (title (string-utf8 100))
    (description (string-utf8 500))
    (budget uint)
    (deadline uint)
)
    (let (
        (job-id (var-get job-nonce))
    )
        (try! (stx-transfer? budget tx-sender (as-contract tx-sender)))
        (map-set jobs job-id {
            employer: tx-sender,
            title: title,
            description: description,
            budget: budget,
            deadline: deadline,
            filled: false,
            worker: none,
            completed:false
        })
        (var-set job-nonce (+ job-id u1))
        (ok job-id)
    )
)

(define-public (apply-for-job (job-id uint) (proposal (string-utf8 300)))
    (let (
        (job (unwrap! (get-job job-id) err-not-found))
    )
        (asserts! (not (get filled job)) err-already-filled)
        (ok (map-set applications {job-id: job-id, applicant: tx-sender}
            {proposal: proposal, applied-at: stacks-block-height}
        ))
    )
)

(define-public (hire-worker (job-id uint) (worker principal))
    (let (
        (job (unwrap! (get-job job-id) err-not-found))
    )
        (asserts! (is-eq tx-sender (get employer job)) err-unauthorized)
        (asserts! (not (get filled job)) err-already-filled)
        
        (ok (map-set jobs job-id 
            (merge job {filled: true, worker: (some worker)})
        ))
    )
)

(define-public (complete-job (job-id uint))
    (let (
        (job (unwrap! (get-job job-id) err-not-found))
        (worker (unwrap! (get worker job) err-not-found))
        (fee (/ (* (get budget job) (var-get platform-fee)) u10000))
        (payment (- (get budget job) fee))
    )
        (asserts! (is-eq tx-sender (get employer job)) err-unauthorized)
        (asserts! (get filled job) err-not-found)
        
        (map-set jobs job-id (merge job {completed: true}))
        
        (try! (as-contract (stx-transfer? payment tx-sender worker)))
        (try! (as-contract (stx-transfer? fee tx-sender contract-owner)))
        (ok true)
    )
)

(define-public (cancel-job (job-id uint))
    (let (
        (job (unwrap! (get-job job-id) err-not-found))
    )
        (asserts! (is-eq tx-sender (get employer job)) err-unauthorized)
        (asserts! (not (get filled job)) err-already-filled)
        
        (try! (as-contract (stx-transfer? (get budget job) tx-sender (get employer job))))
        (ok true)
    )
)

```
