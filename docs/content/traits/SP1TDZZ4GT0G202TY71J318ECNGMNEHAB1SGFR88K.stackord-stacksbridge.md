---
title: "Trait stackord-stacksbridge"
draft: true
---
```
;; title: sbtc-fundr
;; version:
;; summary:
;; description:

;; Define error codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-INVALID-POSITION (err u103))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u104))

;; Minimum collateral ratio (150%)
(define-constant MIN-COLLATERAL-RATIO u150)

;; Position types
(define-constant TYPE-LONG u1)
(define-constant TYPE-SHORT u2)

;; -----------------------------
;; Data Maps and Variables
;; -----------------------------

;; Track user balances
(define-map balances 
    principal 
    { stx-balance: uint })

;; Track positions
(define-map positions
    uint
    { owner: principal,
      position-type: uint,
      size: uint,
      entry-price: uint,
      leverage: uint,
      collateral: uint,
      liquidation-price: uint,
      opened-at: uint })

;; Position counter
(define-data-var position-counter uint u0)

;; Contract admin
(define-data-var contract-owner principal tx-sender)

;; Price oracle (simplified for testnet)
(define-data-var current-price uint u0)

;; -----------------------------
;; Read-Only Functions
;; -----------------------------

(define-read-only (get-balance (user principal))
    (default-to 
        { stx-balance: u0 }
        (map-get? balances user)))

(define-read-only (get-position (position-id uint))
    (map-get? positions position-id))

(define-read-only (get-current-price)
    (ok (var-get current-price)))

;; Calculate liquidation price
(define-read-only (calculate-liquidation-price
    (entry-price uint)
    (position-type uint)
    (leverage uint))
    (if (is-eq position-type TYPE-LONG)
        ;; Long position liquidation price
        (ok (/ (* entry-price (- u100 (/ u100 leverage))) u100))
        ;; Short position liquidation price
        (ok (/ (* entry-price (+ u100 (/ u100 leverage))) u100))))

;; Get position type as ASCII string (Clarity 4)
(define-read-only (get-position-type-string (position-type uint))
    (if (is-eq position-type TYPE-LONG)
        (ok "LONG")
        (if (is-eq position-type TYPE-SHORT)
            (ok "SHORT")
            (err "UNKNOWN"))))

;; Get position status including time held (Clarity 4)
(define-read-only (get-position-status (position-id uint))
    (match (get-position position-id)
        position
            (let ((time-held (- stacks-block-time (get opened-at position))))
                (ok {
                    owner-string: (unwrap-panic (to-ascii? (get owner position))),
                    position-type-string: (unwrap-panic (get-position-type-string (get position-type position))),
                    time-held: time-held
                }))
        (err "Position not found")))

;; Check if position is at risk of liquidation (Clarity 4)
(define-read-only (is-position-at-risk (position-id uint))
    (match (get-position position-id)
        position
            (let ((current-price-val (var-get current-price))
                  (at-risk (if (is-eq (get position-type position) TYPE-LONG)
                              (<= current-price-val (/ (* (get liquidation-price position) u105) u100))
                              (>= current-price-val (/ (* (get liquidation-price position) u95) u100)))))
                (ok {
                    at-risk: at-risk,
                    at-risk-string: (unwrap-panic (to-ascii? at-risk))
                }))
        (err "Position not found")))

;; -----------------------------
;; Public Functions
;; -----------------------------

;; Deposit collateral
(define-public (deposit-collateral (amount uint))
    (let ((current-balance (get stx-balance (get-balance tx-sender))))
        (ok (map-set balances
            tx-sender
            { stx-balance: (+ current-balance amount) }))))

;; Withdraw collateral
(define-public (withdraw-collateral (amount uint))
    (let ((current-balance (get stx-balance (get-balance tx-sender))))
        (asserts! (>= current-balance amount) ERR-INSUFFICIENT-BALANCE)
        (ok (map-set balances
            tx-sender
            { stx-balance: (- current-balance amount) }))))

```
