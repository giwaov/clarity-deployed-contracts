---
title: "Trait registry"
draft: true
---
```
;; Contract: Unique Name Registry
;; Description: Allows users to claim a unique name on-chain.

(define-map name-registry principal (string-ascii 50))
(define-map name-lookup (string-ascii 50) principal)

(define-constant err-name-exists (err u100))
(define-constant err-already-registered (err u101))

(define-read-only (get-name (user principal))
    (map-get? name-registry user)
)

(define-read-only (get-owner (name (string-ascii 50)))
    (map-get? name-lookup name)
)

(define-public (register-name (name (string-ascii 50)))
    (begin
        ;; Check if name is already taken
        (asserts! (is-none (map-get? name-lookup name)) err-name-exists)
        ;; Check if user already has a name
        (asserts! (is-none (map-get? name-registry tx-sender)) err-already-registered)
        
        ;; Register the name
        (map-set name-registry tx-sender name)
        (map-set name-lookup name tx-sender)
        (ok "Name registered successfully")
    )
)
```
