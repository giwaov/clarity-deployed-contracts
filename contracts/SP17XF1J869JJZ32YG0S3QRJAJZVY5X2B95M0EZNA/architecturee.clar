;; StackPay Architecture
;; - Collision-safe IDs (invoice & receipt)
;; - Processor-gated settlement (no direct money movement here)
;; - Clean read-onlys for backend/webhooks

;; traits
(define-trait invoice-trait (
  (get-invoice
    ((string-ascii 85))
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
      metadata: (string-utf8 256),
      email: (string-utf8 256),
      payment-address: (optional principal),
      webhook-url: (optional (string-ascii 256)),
    })
      uint
    )
  )
))

;; errors and constants
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVOICE_NOT_FOUND (err u101))
(define-constant ERR_INVALID_STATUS (err u102))
(define-constant ERR_INVOICE_ALREADY_PAID (err u103))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u104))
(define-constant ERR_INVALID_AMOUNT (err u105))
(define-constant ERR_INVALID_INPUT (err u107))
(define-constant ERR_INVALID_WEBHOOK (err u108))
(define-constant ERR_INVALID_PRINCIPAL (err u109))

(define-constant STATUS_PENDING u0)
(define-constant STATUS_PAID u1)
(define-constant STATUS_EXPIRED u2)

(define-constant CURRENCY_STX "STX")
(define-constant CURRENCY_SBTC "sBTC")

;; data-vars

(define-data-var owner principal tx-sender)
(define-data-var processor (optional principal) none) ;; set once you deploy processor
(define-data-var invoice-ctr uint u0)
(define-data-var receipt-ctr uint u0)
(define-data-var invoice-total uint u0)
(define-data-var receipt-total uint u0)

;; data-maps

;; Track invoice IDs in order
(define-map invoice-index
  { index: uint }
  { invoice-id: (string-ascii 85) }
)

(define-map receipt-index
  { index: uint }
  { receipt-id: (string-ascii 85) }
)

(define-map merchants
  { merchant: principal }
  {
    is-active: bool,
    webhook-url: (optional (string-ascii 256)),
    fee-recipient: (optional principal),
    created-at: uint,
  }
)

(define-map invoices
  { invoice-id: (string-ascii 85) }
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
    metadata: (string-utf8 256),
    email: (string-utf8 256),
    payment-address: (optional principal), ;; reserved for future
    webhook-url: (optional (string-ascii 256)),
  }
)

(define-map receipts
  { receipt-id: (string-ascii 85) }
  {
    invoice-id: (string-ascii 85),
    payer: principal,
    amount-paid: uint,
    tx-id: (buff 32),
    block-height: uint,
    timestamp: uint,
  }
)

;; private functions

(define-private (new-invoice-id)
  (let ((c (var-get invoice-ctr)))
    (var-set invoice-ctr (+ c u1))
    (concat (concat "INV_" (int-to-ascii stacks-block-height))
      (concat "_" (int-to-ascii c))
    )
  )
)

(define-private (new-receipt-id)
  (let ((c (var-get receipt-ctr)))
    (var-set receipt-ctr (+ c u1))
    (concat (concat "RCP_" (int-to-ascii stacks-block-height))
      (concat "_" (int-to-ascii c))
    )
  )
)

(define-private (valid-principal (p principal))
  (and
    (not (is-eq p 'SP000000000000000000002Q6VF78))
    (not (is-eq p 'ST000000000000000000002AMW42H))
    true
  )
)

;; public functions

(define-public (set-platform-fee-recipient (who principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    ;; store per-merchant; your processor will actually charge fee on withdraw
    (map-set merchants { merchant: who }
      (merge
        (default-to {
          is-active: true,
          webhook-url: none,
          fee-recipient: none,
          created-at: stacks-block-height,
        }
          (map-get? merchants { merchant: who })
        ) { fee-recipient: (some who) }
      ))
    (ok true)
  )
)

(define-public (set-processor (p principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set processor (some p))
    (ok true)
  )
)

(define-public (register-merchant (webhook (optional (string-ascii 256))))
  (begin
    (match webhook
      w (asserts! (is-eq (slice? w u0 u5) (some "https")) ERR_INVALID_WEBHOOK)
      true
    )
    (map-set merchants { merchant: tx-sender } {
      is-active: true,
      webhook-url: webhook,
      fee-recipient: none,
      created-at: stacks-block-height,
    })
    (ok tx-sender)
  )
)

(define-public (create-invoice
    (recipient principal)
    (amount uint)
    (currency (string-ascii 10))
    (expires-in-blocks uint)
    (description (string-utf8 256))
    (metadata (string-utf8 256))
    (email (string-utf8 256))
    (webhook (optional (string-ascii 256)))
  )
  (let (
      (m (unwrap! (map-get? merchants { merchant: tx-sender }) ERR_UNAUTHORIZED))
      (id (new-invoice-id))
      (idx (var-get invoice-total))
      (now stacks-block-height)
    )
    (asserts! (get is-active m) ERR_UNAUTHORIZED)
    (asserts! (valid-principal recipient) ERR_INVALID_PRINCIPAL)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (or (is-eq currency CURRENCY_STX) (is-eq currency CURRENCY_SBTC))
      ERR_INVALID_INPUT
    )
    (asserts! (> expires-in-blocks u0) ERR_INVALID_INPUT)
    (match webhook
      w (asserts! (is-eq (slice? w u0 u5) (some "https")) ERR_INVALID_WEBHOOK)
      true
    )
    (map-set invoices { invoice-id: id } {
      merchant: tx-sender,
      recipient: recipient,
      amount: amount,
      currency: currency,
      status: STATUS_PENDING,
      created-at: now,
      expires-at: (+ now expires-in-blocks),
      paid-at: none,
      description: description,
      metadata: metadata,
      email: email,
      payment-address: none,
      webhook-url: (if (is-some webhook)
        webhook
        (get webhook-url m)
      ),
    })
    (map-set invoice-index { index: idx } { invoice-id: id })
    (var-set invoice-total (+ idx u1))
    (ok id)
  )
)

(define-public (process-payment
    (invoice-id (string-ascii 85))
    (payer principal)
    (amount uint)
    (txid (buff 32))
  )
  (let ((proc (unwrap! (var-get processor) ERR_UNAUTHORIZED)))
    (asserts! (is-eq tx-sender proc) ERR_UNAUTHORIZED)
    (let ((inv (unwrap! (map-get? invoices { invoice-id: invoice-id })
        ERR_INVOICE_NOT_FOUND
      )))
      (asserts! (is-eq (get status inv) STATUS_PENDING) ERR_INVOICE_ALREADY_PAID)
      (asserts! (is-eq amount (get amount inv)) ERR_INSUFFICIENT_PAYMENT)
      (asserts! (< stacks-block-height (get expires-at inv)) ERR_INVALID_STATUS)

      ;; mark paid
      (map-set invoices { invoice-id: invoice-id }
        (merge inv {
          status: STATUS_PAID,
          paid-at: (some stacks-block-height),
        })
      )

      ;; emit receipt
      (let (
          (rid (new-receipt-id))
          (idx (var-get receipt-total))
        )
        (map-set receipts { receipt-id: rid } {
          invoice-id: invoice-id,
          payer: payer,
          amount-paid: amount,
          tx-id: txid,
          block-height: stacks-block-height,
          timestamp: stacks-block-height,
        })
        ;; lightweight event log for backend indexers
        (print {
          event: "invoice-paid",
          invoice-id: invoice-id,
          receipt-id: rid,
          amount: amount,
        })
        (map-set receipt-index { index: idx } { receipt-id: rid })
        (var-set receipt-total (+ idx u1))
        (ok rid)
      )
    )
  )
)

(define-public (expire-invoice (invoice-id (string-ascii 85)))
  (let ((inv (unwrap! (map-get? invoices { invoice-id: invoice-id }) ERR_INVOICE_NOT_FOUND)))
    (asserts!
      (or
        (is-eq tx-sender (get merchant inv))
        (is-eq tx-sender (var-get owner))
      )
      ERR_UNAUTHORIZED
    )
    (asserts! (is-eq (get status inv) STATUS_PENDING) ERR_INVALID_STATUS)
    (asserts! (<= (get expires-at inv) stacks-block-height) ERR_INVALID_STATUS)
    (map-set invoices { invoice-id: invoice-id }
      (merge inv { status: STATUS_EXPIRED })
    )
    (ok true)
  )
)

;; getter functions

(define-read-only (get-merchant (who principal))
  (map-get? merchants { merchant: who })
)

(define-read-only (get-invoice (invoice-id (string-ascii 85)))
  (map-get? invoices { invoice-id: invoice-id })
)

(define-read-only (get-receipt (receipt-id (string-ascii 85)))
  (map-get? receipts { receipt-id: receipt-id })
)

(define-read-only (get-invoice-count)
  (ok (var-get invoice-total))
)

(define-read-only (get-receipt-count)
  (ok (var-get receipt-total))
)

(define-read-only (get-invoice-id (i uint))
  (map-get? invoice-index { index: i })
)

(define-read-only (get-receipt-id (i uint))
  (map-get? receipt-index { index: i })
)

(define-read-only (is-invoice-payable (invoice-id (string-ascii 85)))
  (match (map-get? invoices { invoice-id: invoice-id })
    i (and
      (is-eq (get status i) STATUS_PENDING)
      (< stacks-block-height (get expires-at i))
    )
    false
  )
)
