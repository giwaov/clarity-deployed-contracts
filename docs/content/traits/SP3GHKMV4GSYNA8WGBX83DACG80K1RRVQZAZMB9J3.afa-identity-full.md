---
title: "Trait afa-identity-full"
draft: true
---
```
;; AFA Identity Full - Stacks Version
;; Porting presisi dari Solidity ke Clarity

;; traits
(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; token definitions
(define-non-fungible-token afa-id uint)

;; constants
(define-constant ERR-NOT-OWNER (err u100))
(define-constant ERR-ALREADY-HAS-ID (err u101))
(define-constant ERR-INVALID-SIGNATURE (err u102))
(define-constant ERR-SOULBOUND (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-NOT-TOKEN-OWNER (err u105))
(define-constant ERR-INVALID-TIER (err u106))

;; data vars
(define-data-var last-id uint u0)
(define-data-var owner principal tx-sender)
(define-data-var verifier-pubkey (buff 33) 0x020000000000000000000000000000000000000000000000000000000000000000)
(define-data-var base-uri (string-ascii 256) "")

;; data maps
(define-map price-per-tier uint uint) ;; 0: 1mo, 1: 6mo, 2: 1yr
(define-map premium-expirations uint uint)
(define-map nonces principal uint)

;; initialization
(map-set price-per-tier u0 u400000)   ;; 0.0004 STX (sesuai 0.0004 ether)
(map-set price-per-tier u1 u2500000)  ;; 0.0025 STX
(map-set price-per-tier u2 u5000000)  ;; 0.0050 STX

;; --- Core Logic ---

(define-public (initialize (new-verifier (buff 33)) (new-uri (string-ascii 256)))
    (begin
        (asserts! (is-eq tx-sender (var-get owner)) ERR-NOT-OWNER)
        (var-set verifier-pubkey new-verifier)
        (var-set base-uri new-uri)
        (ok true)
    )
)

;; Mint dengan Signature (Sama dengan mintIdentity di Solidity)
(define-public (mint-identity (signature (buff 65)))
    (let (
        (token-id (+ (var-get last-id) u1))
        (caller tx-sender)
        (nonce (default-to u0 (map-get? nonces caller)))
        ;; Hash msg: "AFA_MINT:" + caller + nonce
        (msg-hash (sha256 (concat (concat 0x4146415f4d494e543a (unwrap-panic (to-consensus-buff? caller))) (unwrap-panic (to-consensus-buff? nonce)))))
    )
        ;; Verify Signature menggunakan SECP256K1
        (asserts! (secp256k1-verify msg-hash signature (var-get verifier-pubkey)) ERR-INVALID-SIGNATURE)
        
        (try! (nft-mint? afa-id token-id caller))
        (map-set nonces caller (+ nonce u1))
        (var-set last-id token-id)
        (ok token-id)
    )
)

;; Admin Mint (Sama dengan adminMint di Solidity)
(define-public (admin-mint (recipient principal))
    (let ((token-id (+ (var-get last-id) u1)))
        (asserts! (is-eq tx-sender (var-get owner)) ERR-NOT-OWNER)
        (try! (nft-mint? afa-id token-id recipient))
        ;; Gratis 1 tahun premium (blok Bitcoin ~52560 blok/tahun)
        (map-set premium-expirations token-id (+ burn-block-height u52560))
        (var-set last-id token-id)
        (ok token-id)
    )
)

;; --- Subscription Logic ---

(define-public (set-price-for-tier (tier uint) (price uint))
    (begin
        (asserts! (is-eq tx-sender (var-get owner)) ERR-NOT-OWNER)
        (ok (map-set price-per-tier tier price))
    )
)

(define-public (upgrade-to-premium (token-id uint) (tier uint))
    (let (
        (price (unwrap! (map-get? price-per-tier tier) ERR-INSUFFICIENT-FUNDS))
        (token-owner (unwrap! (nft-get-owner? afa-id token-id) ERR-NOT-TOKEN-OWNER))
        (current-exp (default-to u0 (map-get? premium-expirations token-id)))
        ;; Durasi blok: 1bln=4320, 6bln=25920, 1thn=52560
        (duration (if (is-eq tier u0) u4320 (if (is-eq tier u1) u25920 (if (is-eq tier u2) u52560 u0))))
        (start-point (if (> current-exp burn-block-height) current-exp burn-block-height))
    )
        (asserts! (is-eq tx-sender token-owner) ERR-NOT-TOKEN-OWNER)
        (asserts! (> duration u0) ERR-INVALID-TIER)
        ;; Transfer STX ke Contract Owner (Withdraw langsung)
        (try! (stx-transfer? price tx-sender (var-get owner)))
        (map-set premium-expirations token-id (+ start-point duration))
        (ok true)
    )
)

;; --- Read Only Functions ---

(define-read-only (is-premium (token-id uint))
    (ok (> (default-to u0 (map-get? premium-expirations token-id)) burn-block-height))
)

(define-read-only (get-identity (user principal))
    (ok (map-get? nonces user)) ;; Placeholder untuk ABI kompatibilitas
)

(define-read-only (get-token-uri (token-id uint))
    (ok (some (var-get base-uri)))
)

;; --- NFT Trait Functions ---

(define-public (transfer (id uint) (sender principal) (recipient principal))
    ERR-SOULBOUND
)

(define-read-only (get-last-token-id) (ok (var-get last-id)))
(define-read-only (get-owner (id uint)) (ok (nft-get-owner? afa-id id)))

```
