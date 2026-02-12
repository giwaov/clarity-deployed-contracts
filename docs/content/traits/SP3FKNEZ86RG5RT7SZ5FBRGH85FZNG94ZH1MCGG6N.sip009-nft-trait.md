---
title: "Trait sip009-nft-trait"
draft: true
---
```
;; SIP-009 NFT Trait
;; Standard trait for Non-Fungible Tokens on Stacks

(define-trait nft-trait
  (
    ;; Get the last token ID
    (get-last-token-id () (response uint uint))
    
    ;; Get the token URI
    (get-token-uri (uint) (response (optional (string-ascii 256)) uint))
    
    ;; Get the owner of a token
    (get-owner (uint) (response (optional principal) uint))
    
    ;; Transfer a token
    (transfer (uint principal principal) (response bool uint))
  )
)

```
