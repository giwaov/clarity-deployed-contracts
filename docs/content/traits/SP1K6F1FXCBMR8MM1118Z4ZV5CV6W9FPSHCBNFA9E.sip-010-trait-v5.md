---
title: "Trait sip-010-trait-v5"
draft: true
---
```
(define-trait sip-010-trait
  (
    ;; Transfer from the caller to a new principal
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))

    ;; the human readable name of the token
    (get-name () (response (string-ascii 32) uint))

    ;; the ticker symbol, or empty if none
    (get-symbol () (response (string-ascii 10) uint))

    ;; the number of decimals used, e.g. 6 or 8
    (get-decimals () (response uint uint))

    ;; the balance of the passed principal
    (get-balance (principal) (response uint uint))

    ;; the current total supply (optional)
    (get-total-supply () (response uint uint))

    ;; an optional URI for metadata of this token
    (get-token-uri () (response (optional (string-ascii 256)) uint))
  )
)

```
