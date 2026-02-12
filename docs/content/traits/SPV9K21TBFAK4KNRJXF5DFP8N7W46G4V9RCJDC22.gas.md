---
title: "Trait gas"
draft: true
---
```
(define-constant deployer tx-sender)
(define-constant err-unauthorized (err u401))
(define-constant err-no-pending (err u402))
(define-constant err-cooldown-not-passed (err u403))
(define-constant err-amount-too-high (err u404))
(define-constant max-gas-change u10000)
(define-constant cooldown-blocks u144)

(define-data-var sponsor principal tx-sender)
(define-data-var gas uint u2)

(define-data-var pending-sponsor (optional principal) none)
(define-data-var pending-sponsor-block uint u0)
(define-data-var pending-gas (optional uint) none)
(define-data-var pending-gas-block uint u0)

(impl-trait .gas-trait.gas-trait)

(define-read-only (get-sponsor)
  (var-get sponsor))

(define-read-only (get-gas)
  (var-get gas))

(define-public (get-gas-amount)
  (ok (var-get gas)))

(define-read-only (get-pending-sponsor)
  {
    pending: (var-get pending-sponsor),
    block: (var-get pending-sponsor-block)
  })

(define-read-only (get-pending-gas)
  {
    pending: (var-get pending-gas),
    block: (var-get pending-gas-block)
  })

(define-public (pay-gas)
  (let ((amount (var-get gas))
        (recipient (var-get sponsor)))
    (print { a: "pay-gas", from: contract-caller, to: recipient, amount: amount })
    (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token transfer
      amount
      contract-caller
      recipient
      none)))

(define-public (propose-sponsor (new-sponsor principal))
  (begin
    (asserts! (is-eq tx-sender (var-get sponsor)) err-unauthorized)
    (var-set pending-sponsor (some new-sponsor))
    (var-set pending-sponsor-block burn-block-height)
    (print { a: "propose-sponsor", new-sponsor: new-sponsor, block: burn-block-height })
    (ok true)))

(define-public (confirm-sponsor)
  (let ((pending (var-get pending-sponsor))
        (proposed-block (var-get pending-sponsor-block)))
    (asserts! (is-eq tx-sender (var-get sponsor)) err-unauthorized)
    (asserts! (is-some pending) err-no-pending)
    (asserts! (>= burn-block-height (+ proposed-block cooldown-blocks)) err-cooldown-not-passed)
    (var-set sponsor (unwrap-panic pending))
    (var-set pending-sponsor none)
    (var-set pending-sponsor-block u0)
    (print { a: "confirm-sponsor", new-sponsor: (unwrap-panic pending) })
    (ok true)))

(define-public (cancel-sponsor-change)
  (begin
    (asserts! (is-eq tx-sender (var-get sponsor)) err-unauthorized)
    (print { a: "cancel-sponsor-change" })
    (var-set pending-sponsor none)
    (var-set pending-sponsor-block u0)
    (ok true)))

(define-public (propose-gas (new-gas uint))
  (begin
    (asserts! (is-eq tx-sender (var-get sponsor)) err-unauthorized)
    (asserts! (<= new-gas max-gas-change) err-amount-too-high)
    (var-set pending-gas (some new-gas))
    (var-set pending-gas-block burn-block-height)
    (print { a: "propose-gas", new-gas: new-gas, block: burn-block-height })
    (ok true)))

(define-public (confirm-gas)
  (let ((pending (var-get pending-gas))
        (proposed-block (var-get pending-gas-block)))
    (asserts! (is-eq tx-sender (var-get sponsor)) err-unauthorized)
    (asserts! (is-some pending) err-no-pending)
    (asserts! (>= burn-block-height (+ proposed-block cooldown-blocks)) err-cooldown-not-passed)
    (var-set gas (unwrap-panic pending))
    (var-set pending-gas none)
    (var-set pending-gas-block u0)
    (print { a: "confirm-gas", new-gas: (unwrap-panic pending) })
    (ok true)))

(define-public (cancel-gas-change)
  (begin
    (asserts! (is-eq tx-sender (var-get sponsor)) err-unauthorized)
    (print { a: "cancel-gas-change" })
    (var-set pending-gas none)
    (var-set pending-gas-block u0)
    (ok true)))

```
