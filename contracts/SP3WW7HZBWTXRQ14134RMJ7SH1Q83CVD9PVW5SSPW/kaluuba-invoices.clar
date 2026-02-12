;; title: kaluuba-invoices
;; version: 1.0.0
;; summary: Invoice management contract for Kaluuba
;; description: Create, track, and pay invoices using usernames

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-invalid-amount (err u300))
(define-constant err-invoice-not-found (err u301))
(define-constant err-unauthorized (err u302))
(define-constant err-invoice-expired (err u303))
(define-constant err-invoice-already-paid (err u304))
(define-constant err-invoice-cancelled (err u305))
(define-constant err-invalid-expiry (err u306))

;; Data Variables
(define-data-var total-invoices uint u0)

;; Data Maps
(define-map invoices
  { invoice-id: uint }
  {
    creator: principal,
    recipient: (optional principal),
    amount: uint,
    description: (string-utf8 256),
    created-at: uint,
    expires-at: uint,
    status: (string-ascii 10),
    paid-by: (optional principal),
    paid-at: (optional uint)
  }
)

(define-map user-invoices
  { user: principal }
  { created: uint, received: uint }
)

;; Private Functions
(define-private (is-invoice-valid (invoice-data {
    creator: principal,
    recipient: (optional principal),
    amount: uint,
    description: (string-utf8 256),
    created-at: uint,
    expires-at: uint,
    status: (string-ascii 10),
    paid-by: (optional principal),
    paid-at: (optional uint)
  }))
  (and
    (is-eq (get status invoice-data) "pending")
    (< stacks-block-height (get expires-at invoice-data))
  )
)

;; Read-only Functions
(define-read-only (get-invoice (invoice-id uint))
  (map-get? invoices { invoice-id: invoice-id })
)

(define-read-only (get-total-invoices)
  (ok (var-get total-invoices))
)

(define-read-only (get-user-invoice-stats (user principal))
  (ok (default-to { created: u0, received: u0 }
    (map-get? user-invoices { user: user })))
)

;; Public Functions
(define-public (create-invoice
  (amount uint)
  (description (string-utf8 256))
  (recipient (optional principal))
  (expires-in-blocks uint))
  (let
    (
      (invoice-id (var-get total-invoices))
      (creator tx-sender)
      (expiry-block (+ stacks-block-height expires-in-blocks))
    )
    ;; Validate amount
    (asserts! (> amount u0) err-invalid-amount)
    
    ;; Validate expiry
    (asserts! (> expires-in-blocks u0) err-invalid-expiry)
    
    ;; Create invoice
    (map-set invoices
      { invoice-id: invoice-id }
      {
        creator: creator,
        recipient: recipient,
        amount: amount,
        description: description,
        created-at: stacks-block-height,
        expires-at: expiry-block,
        status: "pending",
        paid-by: none,
        paid-at: none
      }
    )
    
    ;; Update creator stats
    (let
      ((creator-stats (default-to { created: u0, received: u0 }
        (map-get? user-invoices { user: creator }))))
      (map-set user-invoices
        { user: creator }
        { created: (+ (get created creator-stats) u1), received: (get received creator-stats) }
      )
    )
    
    ;; Increment total invoices
    (var-set total-invoices (+ invoice-id u1))
    
    (ok invoice-id)
  )
)

(define-public (pay-invoice (invoice-id uint))
  (let
    (
      (invoice-data (unwrap! (map-get? invoices { invoice-id: invoice-id }) err-invoice-not-found))
      (payer tx-sender)
      (creator (get creator invoice-data))
      (amount (get amount invoice-data))
    )
    ;; Check invoice is valid
    (asserts! (is-invoice-valid invoice-data) err-invoice-expired)
    
    ;; Check if specific recipient required
    (match (get recipient invoice-data)
      recipient (asserts! (is-eq payer recipient) err-unauthorized)
      true
    )
    
    ;; Transfer payment
    (try! (stx-transfer? amount payer creator))
    
    ;; Update invoice status
    (map-set invoices
      { invoice-id: invoice-id }
      (merge invoice-data {
        status: "paid",
        paid-by: (some payer),
        paid-at: (some stacks-block-height)
      })
    )
    
    ;; Update recipient stats if applicable
    (match (get recipient invoice-data)
      recipient (let
        ((recipient-stats (default-to { created: u0, received: u0 }
          (map-get? user-invoices { user: recipient }))))
        (map-set user-invoices
          { user: recipient }
          { created: (get created recipient-stats), received: (+ (get received recipient-stats) u1) }
        )
      )
      true
    )
    
    (ok true)
  )
)

(define-public (cancel-invoice (invoice-id uint))
  (let
    (
      (invoice-data (unwrap! (map-get? invoices { invoice-id: invoice-id }) err-invoice-not-found))
      (creator (get creator invoice-data))
    )
    ;; Only creator can cancel
    (asserts! (is-eq tx-sender creator) err-unauthorized)
    
    ;; Check invoice is pending
    (asserts! (is-eq (get status invoice-data) "pending") err-invoice-already-paid)
    
    ;; Update status
    (map-set invoices
      { invoice-id: invoice-id }
      (merge invoice-data { status: "cancelled" })
    )
    
    (ok true)
  )
)
