---
title: "Trait sip009-nft-trait"
draft: true
---
```
;; SIP-009 NFT Trait
;; Standard interface for non-fungible tokens on Stacks

(define-trait sip009-nft-trait
  (
    ;; Get the last minted token ID
    (get-last-token-id () (response uint uint))
    
    ;; Get the token URI for metadata
    (get-token-uri (uint) (response (optional (string-ascii 256)) uint))
    
    ;; Get the owner of a token
    (get-owner (uint) (response (optional principal) uint))
    
    ;; Transfer a token
    (transfer (uint principal principal) (response bool uint))
  )
)

```
