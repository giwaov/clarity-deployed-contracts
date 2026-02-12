---
title: "Trait gov-token"
draft: true
---
```
;; Contract: Governance Token
;; Description: A fungible token used for voting power.

(define-fungible-token vote-coin)

(define-public (mint (amount uint) (recipient principal))
    (begin
        ;; In a real DAO, minting is restricted. Here we allow it for testing.
        (ft-mint? vote-coin amount recipient)
    )
)

(define-read-only (get-balance (user principal))
    (ok (ft-get-balance vote-coin user))
)

;; Allows the voting contract to transfer tokens (burn or lock) if needed
(define-public (transfer (amount uint) (sender principal) (recipient principal))
    (ft-transfer? vote-coin amount sender recipient)
)
```
