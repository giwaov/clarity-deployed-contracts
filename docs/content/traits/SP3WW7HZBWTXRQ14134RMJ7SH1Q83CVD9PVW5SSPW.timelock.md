---
title: "Trait timelock"
draft: true
---
```
;; Timelock Contract

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-ready (err u101))

(define-data-var delay uint u144)
(define-data-var next-tx-id uint u1)

(define-map queued-transactions
  uint
  {
    target: principal,
    value: uint,
    eta: uint,
    executed: bool
  }
)

(define-read-only (get-transaction (tx-id uint))
  (map-get? queued-transactions tx-id)
)

(define-public (queue-transaction (target principal) (value uint))
  (let ((tx-id (var-get next-tx-id)))
    (map-set queued-transactions tx-id {
      target: target,
      value: value,
      eta: (+ block-height (var-get delay)),
      executed: false
    })
    (var-set next-tx-id (+ tx-id u1))
    (ok tx-id)
  )
)

(define-public (execute-transaction (tx-id uint))
  (let ((tx (unwrap! (map-get? queued-transactions tx-id) (err u102))))
    (asserts! (>= block-height (get eta tx)) err-not-ready)
    (asserts! (not (get executed tx)) (err u103))
    (map-set queued-transactions tx-id (merge tx { executed: true }))
    (ok true)
  )
)

```
