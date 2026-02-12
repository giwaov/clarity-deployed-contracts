---
title: "Trait nova-trait-non-fungible"
draft: true
---
```
;; nova-trait-non-fungible.clar
;; Standard Nova NFT trait definition (SIP-009 compatible).

(define-trait nova-trait-non-fungible
  (
    ;; Last successful transfer
    (get-last-token-id () (response uint uint))

    ;; URI for metadata
    (get-token-uri (uint) (response (optional (string-ascii 256)) uint))

    ;; Owner of a given token identifier
    (get-owner (uint) (response (optional principal) uint))

    ;; Transfer from the sender to a new principal
    (transfer (uint principal principal) (response bool uint))
  )
)

```
