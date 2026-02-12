---
title: "Trait architecture"
draft: true
---
```
;; title: StackPay Core Contract Architecture
;; summary: Main contract that handles payment invoice creation, tracking, and settlement
;; description: This contract architecture defines the core functionality of the StackPay payment processor with secure input handling.

;; traits
(define-trait invoice-trait (
  (get-invoice
    ((string-ascii 64))
    (
      response
      (optional {
      merchant: principal,
      recipient: principal,
      amount: uint,
      currency: (string-ascii 10),
      status: uint,
      created-at: uint,
      expires-at: uint,
      paid-at: (optional uint),
      description: (string-utf8 256),
      metadata: (string-utf8 512),
      payment-address: (optional principal),
      webhook-url: (optional (string-ascii 256)),
    })
      uint
    )
  )
))

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVOICE_NOT_FOUND (err u101))
(define-constant ERR_INVOICE_EXPIRED (err u102))
(define-constant ERR_INVOICE_ALREADY_PAID (err u103))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u104))
(define-constant ERR_INVALID_AMOUNT (err u105))
(define-constant ERR_REFUND_FAILED (err u106))
(define-constant ERR_INVALID_INPUT (err u107))
(define-constant ERR_INVALID_WEBHOOK (err u108))
(define-constant ERR_INVALID_PRINCIPAL (err u109))
(define-constant ERR_INACTIVE_MERCHANT (err u110))

(define-constant STATUS_PENDING u0)
(define-constant STATUS_PAID u1)
(define-constant STATUS_EXPIRED u2)
(define-constant STATUS_REFUNDED u3)

(define-constant PLATFORM_FEE_BPS u250) ;; 2.5%
(define-constant MAX_INVOICE_EXPIRY u52560) ;; ~1 year in blocks
(define-constant MAX_WEBHOOK_LENGTH u256)
(define-constant MAX_DESCRIPTION_LENGTH u256)
(define-constant MAX_METADATA_LENGTH u512)

;; data maps
(define-map invoices
  { invoice-id: (string-ascii 64) }
  {
    merchant: principal,
    recipient: principal,
    amount: uint,
    currency: (string-ascii 10),
    status: uint,
    created-at: uint,
    expires-at: uint,
    paid-at: (optional uint),
    description: (string-utf8 256),
    metadata: (string-utf8 512),
    payment-address: (optional principal),
    webhook-url: (optional (string-ascii 256)),
  }
)

(define-map merchants
  { merchant: principal }
  {
    is-active: bool,
    webhook-url: (optional (string-ascii 256)),
    api-key-hash: (buff 32),
    fee-recipient: (optional principal),
    created-at: uint,
  }
)

(define-map payment-receipts
  { receipt-id: (string-ascii 64) }
  {
    invoice-id: (string-ascii 64),
    payer: principal,
    amount-paid: uint,
    tx-id: (buff 32),
    block-height: uint,
    timestamp: uint,
  }
)

;; data vars
(define-data-var invoice-counter uint u0)
(define-data-var receipt-counter uint u0)
(define-data-var platform-fee-recipient principal CONTRACT_OWNER)
(define-data-var is-paused bool false)

;; private functions
(define-private (generate-invoice-id)
  (let ((counter (var-get invoice-counter)))
    (var-set invoice-counter (+ counter u1))
    (concat "INV_" (int-to-ascii (+ stacks-block-height counter)))
  )
)

(define-private (generate-receipt-id)
  (let ((counter (var-get receipt-counter)))
    (var-set receipt-counter (+ counter u1))
    (concat "RCP_" (int-to-ascii (+ stacks-block-height counter)))
  )
)

(define-private (calculate-platform-fee (amount uint))
  (let ((fee (/ (* amount PLATFORM_FEE_BPS) u10000)))
    (if (> fee amount)
      u0
      fee
    )
  )
)

(define-private (is-invoice-expired (expires-at uint))
  (> stacks-block-height expires-at)
)

(define-private (validate-currency (c (string-ascii 10)))
  (or (is-eq c "STX") (is-eq c "SBTC"))
)

(define-private (validate-principal (p principal))
  (and
    (not (is-eq p 'SP000000000000000000002Q6VF78)) ;; Burn address
    (not (is-eq p 'ST000000000000000000002AMW42H)) ;; Reserved address
    true
  )
)

(define-private (validate-merchant (m principal))
  (match (map-get? merchants { merchant: m })
    merchant-data (get is-active merchant-data)
    false
  )
)


(define-private (validate-webhook (webhook (optional (string-ascii 256))))
  (match webhook
    url (and
      (<= (len url) MAX_WEBHOOK_LENGTH)
      (> (len url) u8) ;; Ensure URL is longer than just "https://"
      (is-eq (slice? url u0 u8) (some "https://")) ;; Check if URL starts with "https://"
      true
    )
    true
  )
)

;; public functions
(define-public (register-merchant
    (webhook-url (optional (string-ascii 256)))
    (api-key-hash (buff 32))
  )
  (let ((merchant tx-sender))
    (asserts! (validate-principal merchant) ERR_INVALID_PRINCIPAL)
    (asserts! (validate-webhook webhook-url) ERR_INVALID_WEBHOOK)
    (asserts! (> (len api-key-hash) u0) ERR_INVALID_INPUT)
    (map-set merchants { merchant: merchant } {
      is-active: true,
      webhook-url: webhook-url,
      api-key-hash: api-key-hash,
      fee-recipient: none,
      created-at: stacks-block-height,
    })
    (print {
      event: "merchant-registered",
      merchant: merchant,
      block-height: stacks-block-height,
    })
    (ok merchant)
  )
)

(define-public (create-invoice
    (recipient principal)
    (amount uint)
    (currency (string-ascii 10))
    (expires-in-blocks uint)
    (description (string-utf8 256))
    (metadata (string-utf8 512))
    (webhook-url (optional (string-ascii 256)))
  )
  (let (
      (merchant tx-sender)
      (invoice-id (generate-invoice-id))
      (current-height stacks-block-height)
      (expires-at (+ current-height expires-in-blocks))
    )
    (asserts! (validate-principal merchant) ERR_INVALID_PRINCIPAL)
    (asserts! (validate-merchant merchant) ERR_INACTIVE_MERCHANT)
    (asserts! (validate-principal recipient) ERR_INVALID_PRINCIPAL)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (validate-currency currency) ERR_INVALID_INPUT)
    (asserts! (<= expires-in-blocks MAX_INVOICE_EXPIRY) ERR_INVALID_INPUT)
    (asserts! (<= (len description) MAX_DESCRIPTION_LENGTH) ERR_INVALID_INPUT)
    (asserts! (<= (len metadata) MAX_METADATA_LENGTH) ERR_INVALID_INPUT)
    (asserts! (> (len currency) u0) ERR_INVALID_INPUT)
    (asserts! (validate-webhook webhook-url) ERR_INVALID_WEBHOOK)
    (asserts! (not (var-get is-paused)) ERR_UNAUTHORIZED)
    (map-set invoices { invoice-id: invoice-id } {
      merchant: merchant,
      recipient: recipient,
      amount: amount,
      currency: currency,
      status: STATUS_PENDING,
      created-at: current-height,
      expires-at: expires-at,
      paid-at: none,
      description: description,
      metadata: metadata,
      payment-address: none,
      webhook-url: webhook-url,
    })
    (print {
      event: "invoice-created",
      invoice-id: invoice-id,
      merchant: merchant,
      recipient: recipient,
      amount: amount,
      currency: currency,
      expires-at: expires-at,
      block-height: current-height,
    })
    (ok invoice-id)
  )
)

(define-public (process-payment
    (invoice-id (string-ascii 64))
    (payer principal)
    (amount-paid uint)
    (tx-id (buff 32))
  )
  (let (
      (invoice-data (unwrap! (map-get? invoices { invoice-id: invoice-id })
        ERR_INVOICE_NOT_FOUND
      ))
      (receipt-id (generate-receipt-id))
      (current-height stacks-block-height)
    )
    (asserts! (validate-principal payer) ERR_INVALID_PRINCIPAL)
    (asserts! (> (len invoice-id) u0) ERR_INVALID_INPUT)
    (asserts! (> (len tx-id) u0) ERR_INVALID_INPUT)
    (asserts! (> amount-paid u0) ERR_INVALID_AMOUNT)
    (asserts! (is-eq (get status invoice-data) STATUS_PENDING)
      ERR_INVOICE_ALREADY_PAID
    )
    (asserts! (not (is-invoice-expired (get expires-at invoice-data)))
      ERR_INVOICE_EXPIRED
    )
    (asserts! (>= amount-paid (get amount invoice-data)) ERR_INSUFFICIENT_PAYMENT)
    ;; Update invoice status
    (map-set invoices { invoice-id: invoice-id }
      (merge invoice-data {
        status: STATUS_PAID,
        paid-at: (some current-height),
      })
    )
    ;; Create payment receipt
    (map-set payment-receipts { receipt-id: receipt-id } {
      invoice-id: invoice-id,
      payer: payer,
      amount-paid: amount-paid,
      tx-id: tx-id,
      block-height: current-height,
      timestamp: current-height,
    })
    ;; Calculate and handle fees
    (let (
        (platform-fee (calculate-platform-fee amount-paid))
        (merchant-amount (- amount-paid platform-fee))
      )
      (asserts! (>= amount-paid platform-fee) ERR_INVALID_AMOUNT)
      ;; Transfer platform fee
      (if (> platform-fee u0)
        (try! (stx-transfer? platform-fee tx-sender (var-get platform-fee-recipient)))
        true
      )
      ;; Transfer remaining amount to recipient
      (try! (stx-transfer? merchant-amount tx-sender (get recipient invoice-data)))
      (print {
        event: "payment-processed",
        invoice-id: invoice-id,
        receipt-id: receipt-id,
        payer: payer,
        amount-paid: amount-paid,
        platform-fee: platform-fee,
        merchant-amount: merchant-amount,
        block-height: current-height,
      })
      (ok receipt-id)
    )
  )
)

(define-public (expire-invoice (invoice-id (string-ascii 64)))
  (let ((invoice-data (unwrap! (map-get? invoices { invoice-id: invoice-id }) ERR_INVOICE_NOT_FOUND)))
    (asserts! (> (len invoice-id) u0) ERR_INVALID_INPUT)
    (asserts! (is-eq (get status invoice-data) STATUS_PENDING)
      ERR_INVOICE_ALREADY_PAID
    )
    ;; (asserts! (is-invoice-expired (get expires-at invoice-data))
    ;;   ERR_INVOICE_NOT_FOUND
    ;; )
    ;; Update status to expired
    (map-set invoices { invoice-id: invoice-id }
      (merge invoice-data { status: STATUS_EXPIRED })
    )
    (print {
      event: "invoice-expired",
      invoice-id: invoice-id,
      block-height: stacks-block-height,
    })
    (ok true)
  )
)

;; admin functions
(define-public (set-platform-fee-recipient (new-recipient principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (validate-principal new-recipient) ERR_INVALID_PRINCIPAL)
    (var-set platform-fee-recipient new-recipient)
    (ok true)
  )
)

(define-public (set-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set is-paused paused)
    (ok true)
  )
)

;; read only functions
(define-read-only (get-invoice (invoice-id (string-ascii 64)))
  (begin
    (map-get? invoices { invoice-id: invoice-id })
  )
)

(define-read-only (get-receipt (receipt-id (string-ascii 64)))
  (begin
    (map-get? payment-receipts { receipt-id: receipt-id })
  )
)

(define-read-only (get-merchant (merchant principal))
  (begin
    (map-get? merchants { merchant: merchant })
  )
)

(define-read-only (is-invoice-payable (invoice-id (string-ascii 64)))
  (begin
    (match (map-get? invoices { invoice-id: invoice-id })
      invoice-data (and
        (is-eq (get status invoice-data) STATUS_PENDING)
        (not (is-invoice-expired (get expires-at invoice-data)))
      )
      false
    )
  )
)

```
