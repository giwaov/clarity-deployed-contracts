---
title: "Trait mint"
draft: true
---
```
;; Simple NFT Mint Contract

;; Define the NFT
(define-non-fungible-token simple-nft uint)

;; Track the last minted ID
(define-data-var last-id uint u0)

;; Mint a new NFT
(define-public (mint)
  (let ((new-id (+ (var-get last-id) u1)))
    (try! (nft-mint? simple-nft new-id tx-sender))
    (var-set last-id new-id)
    (ok new-id)
  )
)

;; Transfer NFT
(define-public (transfer (id uint) (recipient principal))
  (nft-transfer? simple-nft id tx-sender recipient)
)

;; Get NFT owner
(define-read-only (get-owner (id uint))
  (nft-get-owner? simple-nft id)
)

;; Get total minted
(define-read-only (get-total-minted)
  (var-get last-id)
)
```
