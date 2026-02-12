---
title: "Trait badge-issuer"
draft: true
---
```
;; Badge Issuer

(define-constant contract-owner tx-sender)
(define-data-var next-badge-id uint u1)

(define-map badges uint { recipient: principal, badge-type: (string-ascii 32), issued-at: uint })

(define-public (issue-badge (recipient principal) (badge-type (string-ascii 32)))
  (let ((badge-id (var-get next-badge-id)))
    (asserts! (is-eq tx-sender contract-owner) (err u100))
    (map-set badges badge-id { recipient: recipient, badge-type: badge-type, issued-at: block-height })
    (var-set next-badge-id (+ badge-id u1))
    (ok badge-id)
  )
)

```
