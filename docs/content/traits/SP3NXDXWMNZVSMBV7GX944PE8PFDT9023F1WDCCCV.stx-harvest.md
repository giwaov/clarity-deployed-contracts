---
title: "Trait stx-harvest"
draft: true
---
```
;; stx-harvest contract
;; version: 1
;; thepandemonium.io

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-nft-transfer-failed (err u101))
(define-constant err-insufficient-payment (err u102))
(define-constant err-refund-failed (err u103))
(define-constant err-unapproved-nft (err u104))
(define-constant err-invalid-fee-config (err u105))
(define-constant err-invalid-amount (err u106))
(define-constant err-self-approval (err u107))
(define-constant err-insufficient-balance (err u108))
(define-constant err-not-owner (err u109))
(define-constant err-admin-only (err u110))
(define-constant err-cannot-remove-owner (err u111))
(define-constant err-invalid-recipient (err u112))
(define-constant err-already-admin (err u113))
(define-constant err-contract-paused (err u114))
(define-constant err-not-admin (err u115))

(define-data-var fee-amount uint u1000000)
(define-data-var refund-amount uint u10000)
(define-data-var contract-paused bool false)

(define-map approved-nft-contracts principal bool)
(define-map admins principal bool)

(define-trait nft-trait
    (
        (transfer (uint principal principal) (response bool uint))
        (get-owner (uint) (response (optional principal) uint))
    )
)

(define-private (is-admin (caller principal))
    (or 
        (is-eq caller contract-owner)
        (default-to false (map-get? admins caller))
    )
)

(define-public (harvest 
    (nft-contract <nft-trait>) 
    (token-id uint))
    (let
        (
            (seller contract-caller)
            (fee (var-get fee-amount))
            (refund (var-get refund-amount))
            (contract-principal (contract-of nft-contract))
            (nft-owner (unwrap! (contract-call? nft-contract get-owner token-id) err-not-owner))
        )
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (asserts! (default-to false (map-get? approved-nft-contracts contract-principal)) err-unapproved-nft)
        (asserts! (is-eq (some seller) nft-owner) err-not-owner)
        (asserts! (>= (stx-get-balance seller) fee) err-insufficient-payment)
        (unwrap! (stx-transfer? fee seller (as-contract tx-sender)) err-insufficient-payment)
        (unwrap! (contract-call? nft-contract transfer token-id seller (as-contract tx-sender)) err-nft-transfer-failed)
        (unwrap! (as-contract (stx-transfer? refund tx-sender seller)) err-refund-failed)
        (print {event: "harvest", seller: seller, token-id: token-id, nft-contract: contract-principal, fee: fee, refund: refund})
        (ok {seller: seller, token-id: token-id, sale-price: refund})
    )
)

(define-public (withdraw-stx (amount uint) (recipient principal))
    (begin
        (asserts! (is-admin contract-caller) err-admin-only)
        (asserts! (> amount u0) err-invalid-amount)
        (asserts! (not (is-eq recipient (as-contract tx-sender))) err-invalid-recipient)
        (asserts! (<= amount (stx-get-balance (as-contract tx-sender))) err-insufficient-balance)
        (unwrap! (as-contract (stx-transfer? amount tx-sender recipient)) err-refund-failed)
        (print {event: "withdraw", amount: amount, recipient: recipient})
        (ok true)
    )
)

(define-public (set-fee-amounts (new-fee uint) (new-refund uint))
    (begin
        (asserts! (is-admin contract-caller) err-admin-only)
        (asserts! (> new-fee u0) err-invalid-fee-config)
        (asserts! (> new-refund u0) err-invalid-fee-config)
        (asserts! (>= new-fee new-refund) err-invalid-fee-config)
        (var-set fee-amount new-fee)
        (var-set refund-amount new-refund)
        (print {event: "fee-update", fee: new-fee, refund: new-refund})
        (ok true)
    )
)

(define-public (approve-nft-contract (contract principal) (approved bool))
    (begin
        (asserts! (is-admin contract-caller) err-admin-only)
        (asserts! (not (is-eq contract (as-contract tx-sender))) err-self-approval)
        (map-set approved-nft-contracts contract approved)
        (print {event: "nft-approval", contract: contract, approved: approved})
        (ok true)
    )
)

(define-public (remove-nft-contract (contract principal))
    (begin
        (asserts! (is-admin contract-caller) err-admin-only)
        (asserts! (not (is-eq contract (as-contract tx-sender))) err-self-approval)
        (map-delete approved-nft-contracts contract)
        (print {event: "nft-removal", contract: contract})
        (ok true)
    )
)

(define-public (recover-nft (nft-contract <nft-trait>) (token-id uint) (recipient principal))
    (let
        (
            (contract-principal (contract-of nft-contract))
        )
        (asserts! (is-admin contract-caller) err-admin-only)
        (asserts! (not (is-eq recipient (as-contract tx-sender))) err-invalid-recipient)
        (asserts! (is-some (map-get? approved-nft-contracts contract-principal)) err-unapproved-nft)
        (unwrap! (as-contract (contract-call? nft-contract transfer token-id tx-sender recipient)) err-nft-transfer-failed)
        (print {event: "recover-nft", nft-contract: contract-principal, token-id: token-id, recipient: recipient})
        (ok true)
    )
)

(define-public (add-admin (admin principal))
    (begin
        (asserts! (is-eq contract-caller contract-owner) err-owner-only)
        (asserts! (not (is-eq admin contract-owner)) err-already-admin)
        (asserts! (not (is-eq admin (as-contract tx-sender))) err-self-approval)
        (asserts! (is-none (map-get? admins admin)) err-already-admin)
        (map-set admins admin true)
        (print {event: "admin-added", admin: admin})
        (ok true)
    )
)

(define-public (remove-admin (admin principal))
    (begin
        (asserts! (is-eq contract-caller contract-owner) err-owner-only)
        (asserts! (not (is-eq admin contract-owner)) err-cannot-remove-owner)
        (asserts! (is-some (map-get? admins admin)) err-not-admin)
        (map-delete admins admin)
        (print {event: "admin-removed", admin: admin})
        (ok true)
    )
)

(define-public (set-contract-paused (paused bool))
    (begin
        (asserts! (is-admin contract-caller) err-admin-only)
        (var-set contract-paused paused)
        (print {event: "pause-update", paused: paused})
        (ok true)
    )
)

(define-read-only (check-is-admin (caller principal))
    (ok (is-admin caller))
)

(define-read-only (is-nft-approved (contract principal))
    (ok (default-to false (map-get? approved-nft-contracts contract)))
)

(define-read-only (get-nft-contract-status (contract principal))
    (ok (map-get? approved-nft-contracts contract))
)

(define-read-only (get-contract-balance)
    (ok (stx-get-balance (as-contract tx-sender)))
)

(define-read-only (get-fee-info)
    (ok {
        fee: (var-get fee-amount),
        refund: (var-get refund-amount),
        net-cost: (- (var-get fee-amount) (var-get refund-amount))
    })
)

(define-read-only (is-contract-paused)
    (ok (var-get contract-paused))
)

```
