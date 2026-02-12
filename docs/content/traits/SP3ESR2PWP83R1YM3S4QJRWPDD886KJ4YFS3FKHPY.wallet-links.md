---
title: "Trait wallet-links"
draft: true
---
```
;; Wallet Links

(define-map wallets
  principal
  { linked: bool, label: (string-ascii 30) }
)

(define-public (link-wallet (label (string-ascii 30)))
  (begin
    (asserts! (is-none (map-get? wallets tx-sender)) (err u409))
    (map-set wallets tx-sender { linked: true, label: label })
    (ok true)
  )
)

(define-public (update-label (label (string-ascii 30)))
  (let ((wallet (unwrap! (map-get? wallets tx-sender) (err u404))))
    (map-set wallets tx-sender (merge wallet { label: label }))
    (ok true)
  )
)

(define-public (unlink-wallet)
  (begin
    (asserts! (is-some (map-get? wallets tx-sender)) (err u404))
    (map-delete wallets tx-sender)
    (ok true)
  )
)

(define-read-only (get-wallet (user principal))
  (map-get? wallets user)
)

```
