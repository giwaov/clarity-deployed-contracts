---
title: "Trait governance-proposal"
draft: true
---
```
;; Governance Proposal - Clarity 3

(define-constant err-not-found (err u200))
(define-constant err-not-author (err u201))
(define-constant err-closed (err u202))

(define-map proposals
  uint
  {
    author: principal,
    description: (string-ascii 64),
    created-at: uint,
    open: bool
  }
)

(define-data-var next-proposal-id uint u0)

(define-public (submit (text (string-ascii 64)))
  (let ((id (var-get next-proposal-id)))
    (begin
      (map-set proposals id {
        author: tx-sender,
        description: text,
        created-at: burn-block-height,
        open: true
      })
      (var-set next-proposal-id (+ id u1))
      (ok id)
    )
  )
)

(define-public (close (id uint))
  (match (map-get? proposals id)
    proposal
      (if (not (is-eq tx-sender (get author proposal)))
          err-not-author
          (if (not (get open proposal))
              err-closed
              (begin
                (map-set proposals id {
                  author: (get author proposal),
                  description: (get description proposal),
                  created-at: (get created-at proposal),
                  open: false
                })
                (ok true)
              )
          )
      )
    err-not-found
  )
)

(define-read-only (get-proposal (id uint))
  (map-get? proposals id)
)

```
