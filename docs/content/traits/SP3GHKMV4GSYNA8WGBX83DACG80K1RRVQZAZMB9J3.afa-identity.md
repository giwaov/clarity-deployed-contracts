---
title: "Trait afa-identity"
draft: true
---
```

;; title: afa-identity
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

(define-non-fungible-token afa-id uint)
(define-data-var last-id uint u0)
(define-data-var owner principal tx-sender)

(define-public (admin-mint (recipient principal))
  (let ((id (+ (var-get last-id) u1)))
    (asserts! (is-eq tx-sender (var-get owner)) (err u100))
    (try! (nft-mint? afa-id id recipient))
    (var-set last-id id)
    (ok id)))

(define-public (transfer (id uint) (sender principal) (recipient principal))
  (err u103))

(define-read-only (get-owner (id uint))
  (ok (nft-get-owner? afa-id id)))

```
