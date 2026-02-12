---
title: "Trait giftcard-system"
draft: true
---
```
;; Gift Card System - Track gift cards (no funds held)

(define-map giftcards
  (string-ascii 32)
  {
    creator: principal,
    amount: uint,
    redeemed: bool,
    redeemed-by: (optional principal),
    created-at: uint
  }
)

(define-public (create-giftcard (code (string-ascii 32)) (amount uint))
  (begin
    (asserts! (is-none (map-get? giftcards code)) (err u409))
    (map-set giftcards code {
      creator: tx-sender,
      amount: amount,
      redeemed: false,
      redeemed-by: none,
      created-at: stacks-block-height
    })
    (ok true)
  )
)

(define-public (redeem-giftcard (code (string-ascii 32)))
  (let ((card (unwrap! (map-get? giftcards code) (err u404))))
    (asserts! (not (get redeemed card)) (err u400))
    (map-set giftcards code (merge card {
      redeemed: true,
      redeemed-by: (some tx-sender)
    }))
    (ok (get amount card))
  )
)

(define-read-only (check-giftcard (code (string-ascii 32)))
  (map-get? giftcards code)
)

```
