---
title: "Trait jobs"
draft: true
---
```
;; Contract: Job Board
;; Description: Post open tasks.

(define-map job-listings uint { employer: principal, is-done: bool })
(define-data-var job-id uint u0)

(define-public (post-job)
    (let
        (
            (new-id (+ (var-get job-id) u1))
        )
        (map-set job-listings new-id { employer: tx-sender, is-done: false })
        (var-set job-id new-id)
        (ok new-id)
    )
)

(define-public (mark-complete (id uint))
    (let
        (
            (job (unwrap! (map-get? job-listings id) (err u404)))
        )
        ;; Only employer can mark as done
        (asserts! (is-eq tx-sender (get employer job)) (err u403))
        (map-set job-listings id (merge job { is-done: true }))
        (ok "Job Completed")
    )
)

(define-read-only (get-job (id uint))
    (map-get? job-listings id)
)
```
