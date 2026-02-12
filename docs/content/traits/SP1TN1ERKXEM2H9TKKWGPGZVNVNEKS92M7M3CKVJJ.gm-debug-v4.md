---
title: "Trait gm-debug-v4"
draft: true
---
```
;; GM on Stacks - Simplified for Debugging v4
(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant GM_FEE u100000)
(define-constant NFT_FEE u1000000)

(define-non-fungible-token gm-nft uint)
(define-data-var last-token-id uint u0)
(define-data-var total-gms uint u0)
(define-map UserGM principal (string-ascii 64))
(define-data-var base-uri (string-ascii 256) "ipfs://bafybeid7zjg55ukcb3qvi2dd4psbs7fz4ivds7xgrmsp55nzuwslftxnp4")

(define-read-only (get-last-token-id) (ok (var-get last-token-id)))
(define-read-only (get-token-uri (token-id uint)) (ok (some (var-get base-uri))))
(define-read-only (get-owner (token-id uint)) (ok (nft-get-owner? gm-nft token-id)))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) (err u100))
    (nft-transfer? gm-nft token-id sender recipient)
  )
)

(define-public (say-gm)
  (let (
    (sender tx-sender)
    (current-count (var-get total-gms))
  )
    (try! (stx-transfer? GM_FEE sender CONTRACT_OWNER))
    (map-set UserGM sender "gm")
    (var-set total-gms (+ current-count u1))
    (ok (+ current-count u1))
  )
)

(define-public (mint-gm-nft)
  (let (
    (next-id (+ (var-get last-token-id) u1))
    (buyer tx-sender)
  )
    (try! (stx-transfer? NFT_FEE buyer CONTRACT_OWNER))
    (try! (nft-mint? gm-nft next-id buyer))
    (var-set last-token-id next-id)
    (var-set total-gms (+ (var-get total-gms) u1))
    (ok next-id)
  )
)

(define-public (set-base-uri (new-uri (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err u101))
    (var-set base-uri new-uri)
    (ok true)
  )
)

```
