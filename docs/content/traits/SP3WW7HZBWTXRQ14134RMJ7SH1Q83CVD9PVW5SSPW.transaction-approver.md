---
title: "Trait transaction-approver"
draft: true
---
```
;; Transaction Approver

(define-map transaction-approvals { tx-id: uint, signer: principal } bool)

(define-public (approve-transaction (tx-id uint))
  (begin
    (map-set transaction-approvals { tx-id: tx-id, signer: tx-sender } true)
    (ok true)
  )
)

(define-read-only (has-approved (tx-id uint) (signer principal))
  (default-to false (map-get? transaction-approvals { tx-id: tx-id, signer: signer }))
)

```
