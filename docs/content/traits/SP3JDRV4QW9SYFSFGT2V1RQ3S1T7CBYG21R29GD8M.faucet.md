---
title: "Trait faucet"
draft: true
---
```
;; Token Faucet Contract for Stacks Blockchain
;; A simple faucet that distributes tokens with cooldown period

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-cooldown-active (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-transfer-failed (err u103))

;; Data variables
(define-data-var drip-amount uint u1000000) ;; Amount to drip per request (in micro-tokens)
(define-data-var cooldown-period uint u86400) ;; 24 hours in seconds
(define-data-var faucet-enabled bool true)

;; Data maps
(define-map last-drip-time principal uint)

;; Read-only functions

;; Get the drip amount
(define-read-only (get-drip-amount)
    (ok (var-get drip-amount))
)

;; Get the cooldown period
(define-read-only (get-cooldown-period)
    (ok (var-get cooldown-period))
)

;; Check if faucet is enabled
(define-read-only (is-faucet-enabled)
    (ok (var-get faucet-enabled))
)

;; Get the last drip time for a user
(define-read-only (get-last-drip-time (user principal))
    (ok (default-to u0 (map-get? last-drip-time user)))
)

;; Calculate time until next drip is available
(define-read-only (time-until-next-drip (user principal))
    (let
        (
            (last-time (default-to u0 (map-get? last-drip-time user)))
            (current-time burn-block-height)
            (cooldown (var-get cooldown-period))
            (next-available (+ last-time cooldown))
        )
        (if (>= current-time next-available)
            (ok u0)
            (ok (- next-available current-time))
        )
    )
)

;; Check if user can request tokens
(define-read-only (can-request-tokens (user principal))
    (let
        (
            (last-time (default-to u0 (map-get? last-drip-time user)))
            (current-time burn-block-height)
            (cooldown (var-get cooldown-period))
        )
        (ok (>= current-time (+ last-time cooldown)))
    )
)

;; Get faucet statistics
(define-read-only (get-faucet-info)
    (ok {
        drip-amount: (var-get drip-amount),
        cooldown-period: (var-get cooldown-period),
        enabled: (var-get faucet-enabled)
    })
)
```
