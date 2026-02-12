---
title: "Trait perps"
draft: true
---
```
;; title: PerpsV
;; version:
;; summary:
;; description:

;; STX Options/Perps Contract
;; Simple contract for STX options trading

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_OPTION_NOT_FOUND (err u102))
(define-constant ERR_OPTION_EXPIRED (err u103))
(define-constant ERR_INSUFFICIENT_BALANCE (err u104))
(define-constant ERR_POSITION_NOT_FOUND (err u105))
(define-constant ERR_INSUFFICIENT_MARGIN (err u106))
(define-constant ERR_POSITION_LIQUIDATED (err u107))
(define-constant ERR_INVALID_LEVERAGE (err u108))

;; Perp Constants
(define-constant MAX_LEVERAGE u10)
(define-constant LIQUIDATION_THRESHOLD u80) ;; 80%
(define-constant FUNDING_RATE_PRECISION u1000000)

;; Data Variables
(define-data-var next-option-id uint u1)
(define-data-var next-position-id uint u1)
(define-data-var current-stx-price uint u100000) ;; Mock price in micro-STX
(define-data-var funding-rate uint u0)
(define-data-var total-long-positions uint u0)
(define-data-var total-short-positions uint u0)

;; Data Maps
(define-map options
  uint
  {
    creator: principal,
    strike-price: uint,
    expiry: uint,
    amount: uint,
    premium: uint,
    exercised: bool,
    option-type: (string-ascii 4), ;; "call" or "put"
  }
)

(define-map user-balances
  principal
  uint
)

;; Perpetual Positions Map
(define-map positions
  uint
  {
    trader: principal,
    size: uint,
    entry-price: uint,
    margin: uint,
    leverage: uint,
    is-long: bool,
    liquidated: bool,
    last-funding-payment: uint,
  }
)

;; User positions tracking
(define-map user-positions
  principal
  (list 100 uint)
)

;; Create a new option
(define-public (create-option
    (strike-price uint)
    (expiry uint)
    (amount uint)
    (premium uint)
    (option-type (string-ascii 4))
  )
  (let ((option-id (var-get next-option-id)))
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> expiry stacks-block-height) ERR_INVALID_AMOUNT)
    (asserts! (or (is-eq option-type "call") (is-eq option-type "put"))
      ERR_INVALID_AMOUNT
    )

    (map-set options option-id {
      creator: tx-sender,
      strike-price: strike-price,
      expiry: expiry,
      amount: amount,
      premium: premium,
      exercised: false,
      option-type: option-type,
    })

    (var-set next-option-id (+ option-id u1))
    (ok option-id)
  )
)

;; Buy an option (pay premium)
(define-public (buy-option (option-id uint))
  (let (
      (option-data (unwrap! (map-get? options option-id) ERR_OPTION_NOT_FOUND))
      (premium (get premium option-data))
    )
    (asserts! (< stacks-block-height (get expiry option-data)) ERR_OPTION_EXPIRED)
    (asserts! (>= (stx-get-balance tx-sender) premium) ERR_INSUFFICIENT_BALANCE)

    (try! (stx-transfer? premium tx-sender (get creator option-data)))
    (ok true)
  )
)

;; Exercise an option
(define-public (exercise-option (option-id uint))
  (let ((option-data (unwrap! (map-get? options option-id) ERR_OPTION_NOT_FOUND)))
    (asserts! (< stacks-block-height (get expiry option-data)) ERR_OPTION_EXPIRED)
    (asserts! (not (get exercised option-data)) ERR_INVALID_AMOUNT)

    (map-set options option-id (merge option-data { exercised: true }))

    ;; Simple exercise logic - transfer STX based on option type
    (if (is-eq (get option-type option-data) "call")
      (try! (stx-transfer? (get amount option-data) tx-sender (get creator option-data)))
      (try! (stx-transfer? (get amount option-data) (get creator option-data) tx-sender))
    )

    (ok true)
  )
)

;; Get option details
(define-read-only (get-option (option-id uint))
  (map-get? options option-id)
)

;; Get next option ID
(define-read-only (get-next-option-id)
  (var-get next-option-id)
)

;; Check if option is expired
(define-read-only (is-option-expired (option-id uint))
  (match (map-get? options option-id)
    option-data (>= stacks-block-height (get expiry option-data))
    false
  )
)

```
