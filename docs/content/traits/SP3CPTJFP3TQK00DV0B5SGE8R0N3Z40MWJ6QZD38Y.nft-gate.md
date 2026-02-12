---
title: "Trait nft-gate"
draft: true
---
```
;; nft-gate.clar
;; Check if user holds specific NFT

(use-trait nft-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

(define-public (access-content (nft <nft-trait>))
    (let
        (
            (owner (unwrap! (contract-call? nft get-owner u1) (err u100)))
        )
        (asserts! (is-eq (some tx-sender) owner) (err u101))
        (ok "Access Granted")
    )
)

```
