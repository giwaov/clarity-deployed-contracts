---
title: "Trait multi-currency-oracle-v13"
draft: true
---
```
;; Multi-Currency Oracle Contract
;; Provides price feeds for BTC/USD, STX/USD, and BTC/STX pairs

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u500))
(define-constant err-unauthorized (err u501))
(define-constant err-invalid-price (err u502))
(define-constant err-stale-price (err u503))

;; Maximum price age: 1 hour (6 blocks)
(define-constant max-price-age u6)

;; Price feeds for different pairs
(define-map btc-usd-prices
  { block-height: uint }
  { price: uint, timestamp: uint, reporter: principal }
)

(define-map stx-usd-prices
  { block-height: uint }
  { price: uint, timestamp: uint, reporter: principal }
)

(define-map authorized-reporters principal bool)

;; Latest prices
(define-data-var latest-btc-usd uint u0)
(define-data-var latest-stx-usd uint u0)
(define-data-var latest-block uint u0)

;; Initialize contract owner as authorized reporter
(map-set authorized-reporters contract-owner true)

;; Admin functions
(define-public (add-reporter (reporter principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set authorized-reporters reporter true))
  )
)

;; Submit BTC/USD price
(define-public (submit-btc-price (price uint))
  (let ((current-block stacks-block-height))
    (asserts! (default-to false (map-get? authorized-reporters tx-sender)) err-unauthorized)
    (asserts! (> price u0) err-invalid-price)
    
    (map-set btc-usd-prices
      { block-height: current-block }
      { price: price, timestamp: burn-block-height, reporter: tx-sender }
    )
    
    (var-set latest-btc-usd price)
    (var-set latest-block current-block)
    (ok price)
  )
)

;; Submit STX/USD price
(define-public (submit-stx-price (price uint))
  (let ((current-block stacks-block-height))
    (asserts! (default-to false (map-get? authorized-reporters tx-sender)) err-unauthorized)
    (asserts! (> price u0) err-invalid-price)
    
    (map-set stx-usd-prices
      { block-height: current-block }
      { price: price, timestamp: burn-block-height, reporter: tx-sender }
    )
    
    (var-set latest-stx-usd price)
    (ok price)
  )
)

;; Submit both prices in one transaction
(define-public (submit-prices (btc-usd uint) (stx-usd uint))
  (begin
    (try! (submit-btc-price btc-usd))
    (try! (submit-stx-price stx-usd))
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-btc-usd-price)
  (ok (var-get latest-btc-usd))
)

(define-read-only (get-stx-usd-price)
  (ok (var-get latest-stx-usd))
)

;; Calculate BTC/STX exchange rate
;; Returns: How many STX per BTC (with 6 decimals)
(define-read-only (get-btc-stx-rate)
  (let
    (
      (btc-price (var-get latest-btc-usd))  ;; e.g., 12000000 = $120,000
      (stx-price (var-get latest-stx-usd))  ;; e.g., 150 = $1.50
    )
    (if (and (> btc-price u0) (> stx-price u0))
      ;; BTC/STX = BTC_USD / STX_USD
      ;; Multiply by 1000000 for precision
      (ok (/ (* btc-price u1000000) stx-price))
      (ok u0)
    )
  )
)

;; Convert BTC amount to STX equivalent
;; Input: sats (8 decimals)
;; Output: STX amount (6 decimals)
(define-read-only (convert-btc-to-stx (sats uint))
  (let
    (
      (btc-stx-rate (unwrap-panic (get-btc-stx-rate)))
    )
    (if (> btc-stx-rate u0)
      ;; sats * rate / 100 (adjust for decimal difference: 8 to 6)
      (ok (/ (* sats btc-stx-rate) u100))
      (ok u0)
    )
  )
)

;; Convert STX amount to BTC equivalent
;; Input: STX amount (6 decimals)
;; Output: sats (8 decimals)
(define-read-only (convert-stx-to-btc (stx-amount uint))
  (let
    (
      (btc-stx-rate (unwrap-panic (get-btc-stx-rate)))
    )
    (if (> btc-stx-rate u0)
      ;; stx * 100 / rate (adjust for decimal difference)
      (ok (/ (* stx-amount u100) btc-stx-rate))
      (ok u0)
    )
  )
)

;; Round BTC price to nearest $1000
(define-read-only (round-to-thousands (price uint))
  (let
    (
      (thousands (/ price u100000))
      (remainder (mod price u100000))
    )
    (if (>= remainder u50000)
      (ok (* (+ thousands u1) u100000))
      (ok (* thousands u100000))
    )
  )
)

;; Check if prices are fresh
(define-read-only (is-price-fresh)
  (let
    (
      (current-block stacks-block-height)
      (latest (var-get latest-block))
    )
    (ok (<= (- current-block latest) max-price-age))
  )
)

```
