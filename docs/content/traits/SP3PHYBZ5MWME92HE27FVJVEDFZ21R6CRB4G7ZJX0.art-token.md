---
title: "Trait art-token"
draft: true
---
```
;; Contract: Art Token (NFT)
;; Description: Defines the Non-Fungible Token.

(define-non-fungible-token cool-art uint)
(define-data-var last-id uint u0)

(define-public (mint (recipient principal))
    (let
        (
            (next-id (+ (var-get last-id) u1))
        )
        (var-set last-id next-id)
        (nft-mint? cool-art next-id recipient)
    )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) (err u401))
        (nft-transfer? cool-art token-id sender recipient)
    )
)
```
