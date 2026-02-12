---
title: "Trait donation-tracker"
draft: true
---
```
;; Donation Tracker
(define-map donations {donation-id: uint} {donor: principal, recipient: principal, amount: uint, donated-at: uint, message: (string-ascii 200)})
(define-public (make-donation (donation-id uint) (recipient principal) (amount uint) (donated-at uint) (message (string-ascii 200)))
  (begin (map-set donations {donation-id: donation-id} {donor: tx-sender, recipient: recipient, amount: amount, donated-at: donated-at, message: message}) (ok true)))
(define-read-only (get-donation (donation-id uint))
  (map-get? donations {donation-id: donation-id}))

```
