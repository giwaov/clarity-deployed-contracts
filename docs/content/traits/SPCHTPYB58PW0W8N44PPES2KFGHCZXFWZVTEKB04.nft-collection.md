---
title: "Trait nft-collection"
draft: true
---
```
;; NFT Collection Contract (SIP-009)
;; A simple NFT collection with minting functionality

(define-non-fungible-token stackspunks uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-token-exists (err u102))
(define-constant err-max-supply (err u103))
(define-constant err-token-not-found (err u104))

(define-data-var last-token-id uint u0)
(define-constant max-supply u10000)

;; SIP-009 Functions
(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
    (ok (some (concat "https://api.stackspunks.com/metadata/" (uint-to-ascii token-id))))
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? stackspunks token-id))
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (asserts! (is-eq sender (unwrap! (nft-get-owner? stackspunks token-id) err-token-not-found)) err-not-token-owner)
        (nft-transfer? stackspunks token-id sender recipient)
    )
)

;; Mint function
(define-public (mint (recipient principal))
    (let
        (
            (token-id (+ (var-get last-token-id) u1))
        )
        (asserts! (< (var-get last-token-id) max-supply) err-max-supply)
        (try! (nft-mint? stackspunks token-id recipient))
        (var-set last-token-id token-id)
        (ok token-id)
    )
)

;; Helper function to convert uint to string
(define-read-only (uint-to-ascii (value uint))
    (if (<= value u9)
        (unwrap-panic (element-at "0123456789" value))
        (get r (fold uint-to-ascii-inner 
            0x000000000000000000000000000000000000000000000000000000000000000000000000000000
            {v: value, r: ""}))
    )
)

(define-read-only (uint-to-ascii-inner (i (buff 1)) (d {v: uint, r: (string-ascii 40)}))
    (if (> (get v d) u0)
        {
            v: (/ (get v d) u10),
            r: (unwrap-panic (as-max-len? (concat (unwrap-panic (element-at "0123456789" (mod (get v d) u10))) (get r d)) u40))
        }
        d
    )
)

```
