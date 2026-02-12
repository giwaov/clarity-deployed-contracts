---
title: "Trait square-runes-trait"
draft: true
---
```

(define-trait square-runes-trait
  (
    ;; SIP-010 standard functions
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
    (get-decimals () (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))

    ;; Square Runes extensions
    (mint (uint principal) (response uint uint))
    (burn (uint (optional (buff 64))) (response 
      { sender: principal, amount: uint, destination: (optional (buff 64)), burn-block: uint } 
      uint
    ))
  )
)
```
