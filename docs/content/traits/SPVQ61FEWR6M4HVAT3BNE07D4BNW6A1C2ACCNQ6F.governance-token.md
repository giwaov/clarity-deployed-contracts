---
title: "Trait governance-token"
draft: true
---
```
;; DAO Governance Token
;; SIP-010 compliant fungible token with voting delegation

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-amount (err u103))

;; Token configuration
(define-fungible-token governance-token)
(define-data-var token-name (string-ascii 32) "DAO Governance Token")
(define-data-var token-symbol (string-ascii 10) "DAOG")
(define-data-var token-decimals uint u6)
(define-data-var token-uri (optional (string-utf8 256)) none)

;; Voting power delegation
(define-map delegations principal principal)
(define-map voting-power principal uint)
(define-map vote-snapshots { user: principal, block: uint } uint)

;; SIP-010 Functions

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (asserts! (> amount u0) err-invalid-amount)
        (try! (ft-transfer? governance-token amount sender recipient))
        (update-voting-power sender)
        (update-voting-power recipient)
        (match memo to-print (print to-print) 0x)
        (ok true)
    )
)

(define-read-only (get-name)
    (ok (var-get token-name))
)

(define-read-only (get-symbol)
    (ok (var-get token-symbol))
)

(define-read-only (get-decimals)
    (ok (var-get token-decimals))
)

(define-read-only (get-balance (account principal))
    (ok (ft-get-balance governance-token account))
)

(define-read-only (get-total-supply)
    (ok (ft-get-supply governance-token))
)

(define-read-only (get-token-uri)
    (ok (var-get token-uri))
)

;; Governance-specific functions

(define-public (mint (amount uint) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (try! (ft-mint? governance-token amount recipient))
        (update-voting-power recipient)
        (ok true)
    )
)

(define-public (delegate-votes (delegate principal))
    (begin
        (map-set delegations tx-sender delegate)
        (update-voting-power tx-sender)
        (update-voting-power delegate)
        (ok true)
    )
)

(define-public (revoke-delegation)
    (begin
        (match (map-get? delegations tx-sender)
            current-delegate
                (begin
                    (map-delete delegations tx-sender)
                    (update-voting-power tx-sender)
                    (update-voting-power current-delegate)
                    (ok true)
                )
            (ok true)
        )
    )
)

;; Voting power calculations

(define-private (update-voting-power (user principal))
    (let (
        (balance (ft-get-balance governance-token user))
        (delegated-to (map-get? delegations user))
    )
        (match delegated-to
            delegate
                (map-set voting-power user u0)
            (map-set voting-power user balance)
        )
        true
    )
)

(define-read-only (get-voting-power (user principal))
    (ok (default-to u0 (map-get? voting-power user)))
)

(define-read-only (get-voting-power-at (user principal) (height uint))
    (ok (default-to u0 (map-get? vote-snapshots { user: user, block: height })))
)

(define-public (snapshot-voting-power (height uint))
    (let (
        (power (unwrap-panic (get-voting-power tx-sender)))
    )
        (map-set vote-snapshots { user: tx-sender, block: height } power)
        (ok power)
    )
)

(define-read-only (get-delegate (user principal))
    (ok (map-get? delegations user))
)

;; Initialize with initial supply
(begin
    (try! (ft-mint? governance-token u1000000000000 contract-owner))
    (map-set voting-power contract-owner u1000000000000)
)

```
