---
title: "Trait nova-payment-stream"
draft: true
---
```

;; nova-payment-stream.clar
;; Allows users to set up recurring STX payments to another address.
;; CLARITY VERSION: 2

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-STREAM-NOT-FOUND (err u101))
(define-constant ERR-PAYMENT-DUE (err u102))

(define-map streams
    uint
    {
        sender: principal,
        recipient: principal,
        amount: uint,
        interval-blocks: uint,
        last-payment-block: uint,
        active: bool
    }
)

(define-data-var stream-nonce uint u0)

(define-public (create-stream (recipient principal) (amount uint) (interval uint))
    (let (
        (id (var-get stream-nonce))
    )
    (map-set streams id {
        sender: tx-sender,
        recipient: recipient,
        amount: amount,
        interval-blocks: interval,
        last-payment-block: block-height,
        active: true
    })
    (var-set stream-nonce (+ id u1))
    (ok id))
)

(define-public (process-payment (stream-id uint))
    (let (
        (stream (unwrap! (map-get? streams stream-id) ERR-STREAM-NOT-FOUND))
        (sender (get sender stream))
        (recipient (get recipient stream))
        (amount (get amount stream))
        (due-block (+ (get last-payment-block stream) (get interval-blocks stream)))
    )
    (asserts! (get active stream) (err u103))
    (asserts! (>= block-height due-block) ERR-PAYMENT-DUE)

    ;; In a real pulling scenario, the contract would hold funds. 
    ;; Here we assume the contract holds funds or authorized allowance, 
    ;; but for simplicity in Clarity without allowances for STX, the SENDER must call to top up or we use a vault pattern.
    ;; To make this "pullable", the sender would have to deposit into this contract first.
    ;; Let's assume the contract is a vault.
    
    (let ((balance (stx-get-balance (as-contract tx-sender))))
       ;; This requires the user to have deposited funds into the contract specifically for this stream.
       ;; We found that managing per-user balances is better.
       ;; REFACTOR: Check user balance in contract.
       u0 ;; Placeholder for refactor
    )
    
    (ok true)
    )
)

;; Corrected Pull Pattern: User deposits STX into contract, stream pulls from balance.
(define-map user-balances principal uint)

(define-public (deposit)
    (let (
        (amount (stx-get-balance tx-sender)) ;; simple deposit all or amount param
    )
    (err u999) ;; Placeholder, replaced by explicit amount below
    )
)

(define-public (deposit-stx (amount uint))
    (let (
        (sender tx-sender)
        (current-bal (default-to u0 (map-get? user-balances sender)))
    )
    (try! (stx-transfer? amount sender (as-contract tx-sender)))
    (map-set user-balances sender (+ current-bal amount))
    (ok true))
)

(define-public (execute-stream (stream-id uint))
    (let (
        (stream (unwrap! (map-get? streams stream-id) ERR-STREAM-NOT-FOUND))
        (sender (get sender stream))
        (recipient (get recipient stream))
        (amount (get amount stream))
        (due-block (+ (get last-payment-block stream) (get interval-blocks stream)))
        (sender-bal (default-to u0 (map-get? user-balances sender)))
    )
    (asserts! (get active stream) (err u103))
    (asserts! (>= block-height due-block) ERR-PAYMENT-DUE)
    (asserts! (>= sender-bal amount) (err u104))

    (try! (as-contract (stx-transfer? amount tx-sender recipient)))
    
    (map-set user-balances sender (- sender-bal amount))
    (map-set streams stream-id (merge stream { last-payment-block: block-height }))
    (ok true))
)

```
