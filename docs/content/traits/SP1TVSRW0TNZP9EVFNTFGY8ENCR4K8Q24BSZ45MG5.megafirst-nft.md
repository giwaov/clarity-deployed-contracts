---
title: "Trait megafirst-nft"
draft: true
---
```
(impl-trait .nft-trait.nft-trait)

(define-non-fungible-token megafirst-nft uint)

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-MINT-PAUSED (err u425))
(define-constant ERR-DUPLICATE-IMAGE (err u409))
(define-constant ERR-INVALID-TOKEN-URI (err u422))

(define-data-var last-id uint u0)
(define-data-var mint-paused bool false)
(define-data-var minter principal tx-sender)

(define-map token-uri-by-id uint (string-ascii 256))
(define-map image-hash-by-id uint (buff 32))
(define-map image-hash-used (buff 32) bool)

(define-public (transfer (id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
    (nft-transfer? megafirst-nft id sender recipient)))

(define-read-only (get-owner (id uint))
  (ok (nft-get-owner? megafirst-nft id)))

(define-read-only (get-last-token-id)
  (ok (var-get last-id)))

(define-read-only (get-token-uri (id uint))
  (ok (map-get? token-uri-by-id id)))

(define-read-only (get-image-hash (id uint))
  (ok (map-get? image-hash-by-id id)))

(define-public (set-minter (new-minter principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set minter new-minter)
    (ok true)))

(define-public (pause-mint (paused bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set mint-paused paused)
    (ok paused)))

(define-public (mint-by-service (recipient principal) (token-uri (string-ascii 256)) (image-hash (buff 32)))
  (let ((next-id (+ (var-get last-id) u1)))
    (asserts! (is-eq tx-sender (var-get minter)) ERR-NOT-AUTHORIZED)
    (asserts! (not (var-get mint-paused)) ERR-MINT-PAUSED)
    (asserts! (> (len token-uri) u0) ERR-INVALID-TOKEN-URI)
    (asserts! (is-none (map-get? image-hash-used image-hash)) ERR-DUPLICATE-IMAGE)
    (try! (nft-mint? megafirst-nft next-id recipient))
    (map-set token-uri-by-id next-id token-uri)
    (map-set image-hash-by-id next-id image-hash)
    (map-set image-hash-used image-hash true)
    (var-set last-id next-id)
    (ok next-id)))

```
