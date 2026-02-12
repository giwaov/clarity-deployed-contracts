---
title: "Trait vault-srt"
draft: true
---
```
;; Vault contract for secure asset storage
(define-map vault-balances principal uint)
(define-map vault-owners {vault-id: uint} principal)
(define-data-var vault-counter uint u0)

(define-read-only (get-vault-balance (user principal))
  (default-to u0 (map-get? vault-balances user))
)

(define-public (deposit (amount uint))
  (begin
    (asserts! (> amount u0) (err u1))
    (let ((current (get-vault-balance tx-sender)))
      (ok (map-set vault-balances tx-sender (+ current amount)))
    )
  )
)

(define-public (withdraw (amount uint))
  (let ((current (get-vault-balance tx-sender)))
    (begin
      (asserts! (>= current amount) (err u2))
      (ok (map-set vault-balances tx-sender (- current amount)))
    )
  )
)

(define-public (check-vault-balance (user principal))
  (ok (get-vault-balance user))
)

```
