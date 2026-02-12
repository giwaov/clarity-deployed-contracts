---
title: "Trait wishlist-items"
draft: true
---
```
;; Wishlist Items

(define-map wishlists
  { user: principal, item: uint }
  { added: bool }
)

(define-public (add-to-wishlist (item uint))
  (begin
    (asserts! (is-none (map-get? wishlists { user: tx-sender, item: item })) (err u409))
    (map-set wishlists { user: tx-sender, item: item } { added: true })
    (ok true)
  )
)

(define-public (remove-from-wishlist (item uint))
  (begin
    (asserts! (is-some (map-get? wishlists { user: tx-sender, item: item })) (err u404))
    (map-delete wishlists { user: tx-sender, item: item })
    (ok true)
  )
)

(define-read-only (is-wishlisted (user principal) (item uint))
  (is-some (map-get? wishlists { user: user, item: item }))
)

```
