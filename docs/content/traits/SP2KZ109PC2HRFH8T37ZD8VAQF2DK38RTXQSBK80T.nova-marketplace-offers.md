---
title: "Trait nova-marketplace-offers"
draft: true
---
```

;; nova-marketplace-offers.clar
;; Make offers on unlisted NFTs
;; CLARITY VERSION: 2

(define-map offers
    {token: principal, id: uint, bidder: principal}
    uint
)

(define-public (make-offer (token principal) (id uint) (amount uint))
    (begin
        (map-set offers {token: token, id: id, bidder: tx-sender} amount)
        (ok true)
    )
)

(define-public (accept-offer (token principal) (id uint) (bidder principal))
    (let ((amount (unwrap! (map-get? offers {token: token, id: id, bidder: bidder}) (err u404))))
        ;; Transfer logic
        (ok amount)
    )
)

```
