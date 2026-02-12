---
title: "Trait passkey-nft-simple"
draft: true
---
```
;; passkey-nft-simple.clar
;; Simplified SIP-009 NFT with Clarity 4 passkey authentication
;; Key Clarity 4 features: secp256r1-verify, to-ascii?

(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-SIGNATURE (err u101))
(define-constant ERR-TOKEN-NOT-FOUND (err u102))
(define-constant ERR-NOT-TOKEN-OWNER (err u103))
(define-constant ERR-ALREADY-REGISTERED (err u104))
(define-constant ERR-NOT-REGISTERED (err u105))

;; Data
(define-data-var last-token-id uint u0)
(define-data-var base-uri (string-ascii 200) "https://passkey-nft.vercel.app/api/metadata/")
(define-non-fungible-token passkey-nft uint)
(define-map registered-passkeys principal (buff 33))
(define-map user-nonces principal uint)

;; SIP-009: Get last token ID
(define-read-only (get-last-token-id)
  (ok (var-get last-token-id)))

;; SIP-009: Get token URI (uses Clarity 4 to-ascii?)
(define-read-only (get-token-uri (token-id uint))
  (ok (some (concat (var-get base-uri) (unwrap! (to-ascii? token-id) (ok none))))))

;; SIP-009: Get owner
(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? passkey-nft token-id)))

;; SIP-009: Transfer
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (some sender) (nft-get-owner? passkey-nft token-id)) ERR-NOT-TOKEN-OWNER)
    (nft-transfer? passkey-nft token-id sender recipient)))

;; Register passkey (P-256 compressed public key)
(define-public (register-passkey (public-key (buff 33)))
  (begin
    (asserts! (is-none (map-get? registered-passkeys tx-sender)) ERR-ALREADY-REGISTERED)
    (map-set registered-passkeys tx-sender public-key)
    (map-set user-nonces tx-sender u0)
    (ok true)))

;; Mint with passkey (Clarity 4: secp256r1-verify)
(define-public (mint-with-passkey (message-hash (buff 32)) (signature (buff 64)))
  (let (
    (public-key (unwrap! (map-get? registered-passkeys tx-sender) ERR-NOT-REGISTERED))
    (new-id (+ (var-get last-token-id) u1))
    (nonce (default-to u0 (map-get? user-nonces tx-sender)))
  )
    ;; Clarity 4: Native P-256 signature verification
    (asserts! (secp256r1-verify message-hash signature public-key) ERR-INVALID-SIGNATURE)
    (try! (nft-mint? passkey-nft new-id tx-sender))
    (var-set last-token-id new-id)
    (map-set user-nonces tx-sender (+ nonce u1))
    (ok new-id)))

;; Transfer with passkey authentication
(define-public (transfer-with-passkey 
  (token-id uint) 
  (recipient principal) 
  (message-hash (buff 32)) 
  (signature (buff 64)))
  (let (
    (public-key (unwrap! (map-get? registered-passkeys tx-sender) ERR-NOT-REGISTERED))
    (owner (unwrap! (nft-get-owner? passkey-nft token-id) ERR-TOKEN-NOT-FOUND))
  )
    (asserts! (is-eq owner tx-sender) ERR-NOT-TOKEN-OWNER)
    (asserts! (secp256r1-verify message-hash signature public-key) ERR-INVALID-SIGNATURE)
    (try! (nft-transfer? passkey-nft token-id tx-sender recipient))
    (ok true)))

;; Read-only helpers
(define-read-only (get-passkey (user principal))
  (map-get? registered-passkeys user))

(define-read-only (get-nonce (user principal))
  (default-to u0 (map-get? user-nonces user)))

(define-read-only (is-registered (user principal))
  (is-some (map-get? registered-passkeys user)))

(define-read-only (verify-signature (user principal) (message-hash (buff 32)) (signature (buff 64)))
  (match (map-get? registered-passkeys user)
    pk (ok (secp256r1-verify message-hash signature pk))
    (err ERR-NOT-REGISTERED)))

;; Admin functions
(define-public (set-base-uri (new-uri (string-ascii 200)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set base-uri new-uri)
    (ok true)))

(define-public (admin-mint (recipient principal))
  (let ((new-id (+ (var-get last-token-id) u1)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (try! (nft-mint? passkey-nft new-id recipient))
    (var-set last-token-id new-id)
    (ok new-id)))

```
