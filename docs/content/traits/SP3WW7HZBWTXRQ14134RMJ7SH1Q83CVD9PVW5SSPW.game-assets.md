---
title: "Trait game-assets"
draft: true
---
```
;; Game Assets NFT
;; Gaming NFTs with attributes

(define-constant contract-owner tx-sender)
(define-data-var next-asset-id uint u1)

(define-map assets
  uint
  {
    owner: principal,
    asset-type: (string-ascii 32),
    power: uint,
    rarity: uint
  }
)

(define-read-only (get-asset (asset-id uint))
  (map-get? assets asset-id)
)

(define-public (mint-asset (asset-type (string-ascii 32)) (power uint) (rarity uint))
  (let ((asset-id (var-get next-asset-id)))
    (map-set assets asset-id {
      owner: tx-sender,
      asset-type: asset-type,
      power: power,
      rarity: rarity
    })
    (var-set next-asset-id (+ asset-id u1))
    (ok asset-id)
  )
)

(define-public (transfer-asset (asset-id uint) (recipient principal))
  (let ((asset (unwrap! (map-get? assets asset-id) (err u100))))
    (asserts! (is-eq tx-sender (get owner asset)) (err u101))
    (map-set assets asset-id (merge asset { owner: recipient }))
    (ok true)
  )
)

```
