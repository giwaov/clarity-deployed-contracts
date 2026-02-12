---
title: "Trait molt-vault"
draft: true
---
```
;; Molt Vault - Simple STX deposit/withdraw vault
;; Hardcoded contract principal to avoid Clarity version issues

(define-map balances principal uint)

(define-constant err-insufficient-balance (err u101))
(define-constant err-zero-amount (err u102))

;; IMPORTANT: This is your deployer address from the failed tx
;; Contract principal = your address + .contract-name
;; If you change the contract name (e.g., to molt-vault-v2), update the name here too
(define-constant contract-principal 'SP29VJHHXFPRQMW6W1VDE9NVR4AZ04V44H3T1X01Y.molt-vault)

(define-public (deposit (amount uint))
  (begin
    (asserts! (> amount u0) err-zero-amount)
    (try! (stx-transfer? amount tx-sender contract-principal))
    (ok (map-set balances
                 tx-sender
                 (+ (default-to u0 (map-get? balances tx-sender)) amount)))
  )
)

(define-public (withdraw (amount uint))
  (let ((sender tx-sender)
        (current (default-to u0 (map-get? balances sender))))
    (asserts! (> amount u0) err-zero-amount)
    (asserts! (>= current amount) err-insufficient-balance)
    ;; Transfer STX first (from contract to user)
    (try! (stx-transfer? amount contract-principal sender))
    ;; Then update balance (only if transfer succeeds)
    (ok (map-set balances sender (- current amount)))
  )
)

(define-read-only (get-balance (user principal))
  (ok (default-to u0 (map-get? balances user)))
)
```
