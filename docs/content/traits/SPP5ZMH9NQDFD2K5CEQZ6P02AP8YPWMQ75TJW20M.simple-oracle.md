---
title: "Trait simple-oracle"
draft: true
---
```
;; simple-oracle - x402 Payment-Gated Endpoint (Mainnet)
;; Deployed by Stacks Endpoint Deployer

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_PAYMENT_REQUIRED (err u402))
(define-constant PRICE_STX u1000)
(define-constant PAYMENT_RECIPIENT 'SPP5ZMH9NQDFD2K5CEQZ6P02AP8YPWMQ75TJW20M)

(define-data-var contract-paused bool false)
(define-data-var total-calls uint u0)
(define-data-var total-revenue uint u0)

(define-map user-calls principal uint)
(define-map allowlist principal bool)

(define-private (is-owner)
  (is-eq tx-sender CONTRACT_OWNER)
)

(define-private (increment-calls)
  (begin
    (var-set total-calls (+ (var-get total-calls) u1))
    (map-set user-calls tx-sender
      (+ (default-to u0 (map-get? user-calls tx-sender)) u1))
  )
)

(define-read-only (get-info)
  (ok {
    name: "simple-oracle",
    price-stx: PRICE_STX,
    total-calls: (var-get total-calls),
    total-revenue: (var-get total-revenue),
    paused: (var-get contract-paused)
  })
)

(define-read-only (get-price)
  (ok {
    stx: PRICE_STX,
    recipient: PAYMENT_RECIPIENT
  })
)

(define-public (call-with-stx)
  (begin
    (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
    (if (default-to false (map-get? allowlist tx-sender))
      (begin
        (increment-calls)
        (ok {
          result: "success",
          block-height: block-height,
          caller: tx-sender,
          call-number: (var-get total-calls)
        })
      )
      (begin
        (try! (stx-transfer? PRICE_STX tx-sender PAYMENT_RECIPIENT))
        (increment-calls)
        (var-set total-revenue (+ (var-get total-revenue) PRICE_STX))
        (ok {
          result: "success",
          block-height: block-height,
          caller: tx-sender,
          call-number: (var-get total-calls)
        })
      )
    )
  )
)

(define-public (set-paused (paused bool))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set contract-paused paused)
    (ok true)
  )
)

(define-public (add-to-allowlist (user principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (map-set allowlist user true)
    (ok true)
  )
)

```
