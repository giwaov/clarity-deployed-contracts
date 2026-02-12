---
title: "Trait market-factory"
draft: true
---
```
;; Market Factory Contract

(define-data-var next-market-id uint u1)

(define-map markets
  uint
  {
    creator: principal,
    question: (string-ascii 256),
    end-time: uint,
    resolved: bool,
    outcome: (optional uint)
  }
)

(define-read-only (get-market (market-id uint))
  (map-get? markets market-id)
)

(define-public (create-market (question (string-ascii 256)) (duration uint))
  (let ((market-id (var-get next-market-id)))
    (map-set markets market-id {
      creator: tx-sender,
      question: question,
      end-time: (+ block-height duration),
      resolved: false,
      outcome: none
    })
    (var-set next-market-id (+ market-id u1))
    (ok market-id)
  )
)

```
