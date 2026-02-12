---
title: "Trait nova-rental-registry"
draft: true
---
```

;; nova-rental-registry.clar
;; Rent NFTs
;; CLARITY VERSION: 2

(define-map rentals
    {token: principal, id: uint}
    {
        renter: principal,
        expires: uint
    }
)

(define-public (rent-item (token principal) (id uint) (duration uint))
    (begin
        ;; Payment logic
        (map-set rentals {token: token, id: id} {
            renter: tx-sender,
            expires: (+ block-height duration)
        })
        (ok true)
    )
)

(define-read-only (get-user (token principal) (id uint))
    (let ((rental (map-get? rentals {token: token, id: id})))
        (match rental
            r (if (> (get expires r) block-height) (some (get renter r)) none)
            none
        )
    )
)

```
