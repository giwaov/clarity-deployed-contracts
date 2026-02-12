---
title: "Trait multi-sig-simple"
draft: true
---
```
;; Simple Multi-Sig - Multi-signature approvals

(define-map proposals
  uint
  {
    proposer: principal,
    approvals: uint,
    executed: bool
  }
)

(define-map approvals { proposal-id: uint, signer: principal } { approved: bool })

(define-data-var proposal-counter uint u0)
(define-data-var required-sigs uint u2)

(define-public (create-proposal)
  (let ((id (var-get proposal-counter)))
    (map-set proposals id {
      proposer: tx-sender,
      approvals: u0,
      executed: false
    })
    (var-set proposal-counter (+ id u1))
    (ok id)
  )
)

(define-public (approve-proposal (id uint))
  (let ((proposal (unwrap! (map-get? proposals id) (err u404))))
    (asserts! (is-none (map-get? approvals { proposal-id: id, signer: tx-sender })) (err u400))
    (map-set approvals { proposal-id: id, signer: tx-sender } { approved: true })
    (map-set proposals id (merge proposal { approvals: (+ (get approvals proposal) u1) }))
    (ok true)
  )
)

(define-read-only (get-proposal (id uint))
  (map-get? proposals id)
)

```
