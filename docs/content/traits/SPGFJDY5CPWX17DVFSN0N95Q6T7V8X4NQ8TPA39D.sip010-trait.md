---
title: "Trait sip010-trait"
draft: true
---
```
;; SIP-010 Fungible Token Trait v2
;; Standard interface for fungible tokens on Stacks

(define-trait sip010-trait
  (
    ;; Transfer tokens from sender to recipient
    ;; @param amount: number of tokens to transfer
    ;; @param sender: principal sending tokens
    ;; @param recipient: principal receiving tokens
    ;; @param memo: optional memo (max 34 bytes)
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))

    ;; Get the human-readable name of the token
    (get-name () (response (string-ascii 32) uint))

    ;; Get the ticker symbol
    (get-symbol () (response (string-ascii 32) uint))

    ;; Get the number of decimals (e.g., 6 means 1_000_000 = 1 token)
    (get-decimals () (response uint uint))

    ;; Get the balance of a principal
    (get-balance (principal) (response uint uint))

    ;; Get the current total supply
    (get-total-supply () (response uint uint))

    ;; Get optional URI for token metadata
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

```
