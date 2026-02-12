---
title: "Trait AhoraSiQueSi"
draft: true
---
```
;; basic-nft.clar
;; Compatible con Clarity 3

(define-non-fungible-token basic-nft uint)

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-NOT-OWNER (err u201))

;; Mapa opcional de metadata (off-chain pointer)
(define-map token-uri
  { token-id: uint }
  { uri: (string-utf8 256) }
)

;; Leer propietario del NFT
(define-read-only (get-owner (token-id uint))
  (nft-get-owner? basic-nft token-id)
)

;; Leer metadata
(define-read-only (get-token-uri (token-id uint))
  (map-get? token-uri { token-id: token-id })
)

;; Mint NFT (solo el deployer)
(define-public (mint
  (token-id uint)
  (recipient principal)
  (uri (string-utf8 256))
)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (try! (nft-mint? basic-nft token-id recipient))
    (map-set token-uri { token-id: token-id } { uri: uri })
    (ok true)
  )
)

;; Transferencia NFT
(define-public (transfer
  (token-id uint)
  (sender principal)
  (recipient principal)
)
  (begin
    (asserts!
      (is-eq (some sender) (nft-get-owner? basic-nft token-id))
      ERR-NOT-OWNER
    )
    (nft-transfer? basic-nft token-id sender recipient)
  )
)
```
