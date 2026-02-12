;; Payment Gateway
;; A comprehensive payment gateway for businesses to accept sBTC payments
;; Built for the Stacks blockchain with Bitcoin settlement

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PAYMENT_NOT_FOUND (err u101))
(define-constant ERR_PAYMENT_ALREADY_PROCESSED (err u102))
(define-constant ERR_INSUFFICIENT_AMOUNT (err u103))
(define-constant ERR_INVALID_MERCHANT (err u104))
(define-constant ERR_PAYMENT_EXPIRED (err u105))
(define-constant ERR_INVALID_AMOUNT (err u106))
(define-constant ERR_MERCHANT_NOT_REGISTERED (err u107))
(define-constant ERR_REFUND_FAILED (err u108))
(define-constant ERR_INVALID_FEE_RATE (err u109))

;; sBTC token reference
(define-constant SBTC_TOKEN_CONTRACT 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token)

;; Data Variables
(define-data-var payment-counter uint u0)
(define-data-var platform-fee-rate uint u250) ;; 2.5% in basis points (250/10000)
(define-data-var min-payment-amount uint u1000) ;; Minimum payment in microBTC
(define-data-var payment-expiry-blocks uint u144) ;; ~24 hours at 10min/block

;; Data Maps
(define-map merchants
  principal
  {
    is-active: bool,
    business-name: (string-ascii 100),
    webhook-url: (optional (string-ascii 200)),
    fee-rate: uint, ;; custom fee rate for merchant (basis points)
    total-volume: uint,
    payment-count: uint,
    created-at: uint,
  }
)

(define-map payments
  uint
  {
    payment-id: uint,
    merchant: principal,
    customer: (optional principal),
    amount: uint,
    fee-amount: uint,
    status: (string-ascii 20), ;; "pending", "completed", "refunded", "expired"
    description: (string-ascii 200),
    external-id: (optional (string-ascii 100)), ;; merchant's order/invoice ID
    created-at: uint,
    expires-at: uint,
    completed-at: (optional uint),
    refunded-at: (optional uint),
  }
)

(define-map payment-callbacks
  uint
  {
    callback-url: (optional (string-ascii 200)),
    callback-data: (optional (string-ascii 500)),
  }
)

;; Authorization map for merchant staff/delegates
(define-map merchant-authorizations
  {
    merchant: principal,
    delegate: principal,
  }
  bool
)

;; Read-only functions

(define-read-only (get-payment (payment-id uint))
  (map-get? payments payment-id)
)

(define-read-only (get-merchant (merchant-address principal))
  (map-get? merchants merchant-address)
)

(define-read-only (get-payment-callback (payment-id uint))
  (map-get? payment-callbacks payment-id)
)

(define-read-only (get-platform-fee-rate)
  (var-get platform-fee-rate)
)

(define-read-only (get-min-payment-amount)
  (var-get min-payment-amount)
)

(define-read-only (get-payment-expiry-blocks)
  (var-get payment-expiry-blocks)
)

(define-read-only (calculate-fee
    (amount uint)
    (merchant principal)
  )
  (let (
      (merchant-info (unwrap! (map-get? merchants merchant) (err ERR_MERCHANT_NOT_REGISTERED)))
      (fee-rate (get fee-rate merchant-info))
      (effective-rate (if (> fee-rate u0)
        fee-rate
        (var-get platform-fee-rate)
      ))
    )
    (ok (/ (* amount effective-rate) u10000))
  )
)

(define-read-only (is-merchant-authorized
    (merchant principal)
    (delegate principal)
  )
  (or
    (is-eq merchant delegate)
    (default-to false
      (map-get? merchant-authorizations {
        merchant: merchant,
        delegate: delegate,
      })
    )
  )
)

(define-read-only (get-payment-status (payment-id uint))
  (match (map-get? payments payment-id)
    payment-data (ok (get status payment-data))
    (err ERR_PAYMENT_NOT_FOUND)
  )
)

(define-read-only (is-payment-expired (payment-id uint))
  (match (map-get? payments payment-id)
    payment-data (let ((expires-at (get expires-at payment-data)))
      (ok (>= stacks-block-height expires-at))
    )
    (err ERR_PAYMENT_NOT_FOUND)
  )
)

;; Private functions

(define-private (update-merchant-stats
    (merchant principal)
    (amount uint)
  )
  (match (map-get? merchants merchant)
    merchant-data (map-set merchants merchant
      (merge merchant-data {
        total-volume: (+ (get total-volume merchant-data) amount),
        payment-count: (+ (get payment-count merchant-data) u1),
      })
    )
    false
  )
)

;; Public functions

;; Register a new merchant
(define-public (register-merchant
    (business-name (string-ascii 100))
    (webhook-url (optional (string-ascii 200)))
    (custom-fee-rate uint)
  )
  (begin
    (asserts! (<= custom-fee-rate u1000) (err ERR_INVALID_FEE_RATE)) ;; Max 10% fee
    (ok (map-set merchants tx-sender {
      is-active: true,
      business-name: business-name,
      webhook-url: webhook-url,
      fee-rate: custom-fee-rate,
      total-volume: u0,
      payment-count: u0,
      created-at: stacks-block-height,
    }))
  )
)

;; Update merchant settings
(define-public (update-merchant-settings
    (business-name (optional (string-ascii 100)))
    (webhook-url (optional (string-ascii 200)))
    (custom-fee-rate (optional uint))
  )
  (let ((current-merchant (unwrap! (map-get? merchants tx-sender) (err ERR_MERCHANT_NOT_REGISTERED))))
    (begin
      (if (is-some custom-fee-rate)
        (asserts! (<= (unwrap-panic custom-fee-rate) u1000)
          (err ERR_INVALID_FEE_RATE)
        )
        true
      )
      (ok (map-set merchants tx-sender
        (merge current-merchant {
          business-name: (default-to (get business-name current-merchant) business-name),
          webhook-url: (if (is-some webhook-url)
            webhook-url
            (get webhook-url current-merchant)
          ),
          fee-rate: (default-to (get fee-rate current-merchant) custom-fee-rate),
        })
      ))
    )
  )
)

;; Authorize a delegate to act on behalf of merchant
(define-public (authorize-delegate (delegate principal))
  (begin
    (asserts! (is-some (map-get? merchants tx-sender))
      (err ERR_MERCHANT_NOT_REGISTERED)
    )
    (ok (map-set merchant-authorizations {
      merchant: tx-sender,
      delegate: delegate,
    }
      true
    ))
  )
)

;; Revoke delegate authorization
(define-public (revoke-delegate (delegate principal))
  (begin
    (asserts! (is-some (map-get? merchants tx-sender))
      (err ERR_MERCHANT_NOT_REGISTERED)
    )
    (ok (map-delete merchant-authorizations {
      merchant: tx-sender,
      delegate: delegate,
    }))
  )
)

;; Create a new payment request
(define-public (create-payment-request
    (amount uint)
    (description (string-ascii 200))
    (external-id (optional (string-ascii 100)))
    (callback-url (optional (string-ascii 200)))
    (callback-data (optional (string-ascii 500)))
  )
  (let (
      (payment-id (+ (var-get payment-counter) u1))
      (merchant-info (unwrap! (map-get? merchants tx-sender) (err ERR_MERCHANT_NOT_REGISTERED)))
      (fee-amount (unwrap! (calculate-fee amount tx-sender) (err ERR_INVALID_AMOUNT)))
      (expires-at (+ stacks-block-height (var-get payment-expiry-blocks)))
    )
    (begin
      (asserts! (get is-active merchant-info) (err ERR_INVALID_MERCHANT))
      (asserts! (>= amount (var-get min-payment-amount)) (err ERR_INVALID_AMOUNT))

      ;; Update payment counter
      (var-set payment-counter payment-id)

      ;; Create payment record
      (map-set payments payment-id {
        payment-id: payment-id,
        merchant: tx-sender,
        customer: none,
        amount: amount,
        fee-amount: fee-amount,
        status: "pending",
        description: description,
        external-id: external-id,
        created-at: stacks-block-height,
        expires-at: expires-at,
        completed-at: none,
        refunded-at: none,
      })

      ;; Store callback information if provided
      (if (or (is-some callback-url) (is-some callback-data))
        (map-set payment-callbacks payment-id {
          callback-url: callback-url,
          callback-data: callback-data,
        })
        true
      )

      (ok payment-id)
    )
  )
)

;; Process a payment (customer pays)
(define-public (process-payment (payment-id uint))
  (let (
      (payment-data (unwrap! (map-get? payments payment-id) (err ERR_PAYMENT_NOT_FOUND)))
      (merchant (get merchant payment-data))
      (amount (get amount payment-data))
      (fee-amount (get fee-amount payment-data))
      (net-amount (- amount fee-amount))
    )
    (begin
      ;; Validate payment state
      (asserts! (is-eq (get status payment-data) "pending")
        (err ERR_PAYMENT_ALREADY_PROCESSED)
      )
      (asserts! (< stacks-block-height (get expires-at payment-data))
        (err ERR_PAYMENT_EXPIRED)
      )

      ;; Transfer full amount from customer to merchant first
      (unwrap! (contract-call? SBTC_TOKEN_CONTRACT transfer amount tx-sender merchant none)
        (err ERR_INSUFFICIENT_AMOUNT)
      )

      ;; Transfer fee from merchant to contract owner if fee > 0
      (and (> fee-amount u0)
        (unwrap! (as-contract (contract-call? SBTC_TOKEN_CONTRACT transfer fee-amount merchant CONTRACT_OWNER none))
          (err ERR_INSUFFICIENT_AMOUNT)
        )
      )

      ;; Update payment status
      (map-set payments payment-id
        (merge payment-data {
          customer: (some tx-sender),
          status: "completed",
          completed-at: (some stacks-block-height),
        })
      )

      ;; Update merchant statistics
      (update-merchant-stats merchant amount)

      (ok true)
    )
  )
)

;; Refund a payment (merchant initiates)
(define-public (refund-payment (payment-id uint))
  (let (
      (payment-data (unwrap! (map-get? payments payment-id) (err ERR_PAYMENT_NOT_FOUND)))
      (merchant (get merchant payment-data))
      (customer (unwrap! (get customer payment-data) (err ERR_PAYMENT_NOT_FOUND)))
      (amount (get amount payment-data))
      (fee-amount (get fee-amount payment-data))
    )
    (begin
      ;; Validate authorization
      (asserts! (is-merchant-authorized merchant tx-sender)
        (err ERR_UNAUTHORIZED)
      )
      (asserts! (is-eq (get status payment-data) "completed")
        (err ERR_PAYMENT_ALREADY_PROCESSED)
      )

      ;; Transfer amount back to customer
      (unwrap! (contract-call? SBTC_TOKEN_CONTRACT transfer amount merchant customer none)
        (err ERR_REFUND_FAILED)
      )

      ;; Update payment status
      (map-set payments payment-id
        (merge payment-data {
          status: "refunded",
          refunded-at: (some stacks-block-height),
        })
      )

      (ok true)
    )
  )
)

;; Mark expired payments (can be called by anyone for cleanup)
(define-public (mark-expired-payment (payment-id uint))
  (let ((payment-data (unwrap! (map-get? payments payment-id) (err ERR_PAYMENT_NOT_FOUND))))
    (begin
      (asserts! (is-eq (get status payment-data) "pending")
        (err ERR_PAYMENT_ALREADY_PROCESSED)
      )
      (asserts! (>= stacks-block-height (get expires-at payment-data))
        (err ERR_PAYMENT_EXPIRED)
      )

      (ok (map-set payments payment-id (merge payment-data { status: "expired" })))
    )
  )
)

;; Admin functions (only contract owner)

(define-public (set-platform-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_UNAUTHORIZED))
    (asserts! (<= new-rate u1000) (err ERR_INVALID_FEE_RATE)) ;; Max 10%
    (ok (var-set platform-fee-rate new-rate))
  )
)

(define-public (set-min-payment-amount (new-amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_UNAUTHORIZED))
    (ok (var-set min-payment-amount new-amount))
  )
)

(define-public (set-payment-expiry-blocks (new-expiry uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_UNAUTHORIZED))
    (ok (var-set payment-expiry-blocks new-expiry))
  )
)

(define-public (deactivate-merchant (merchant principal))
  (let ((merchant-data (unwrap! (map-get? merchants merchant) (err ERR_MERCHANT_NOT_REGISTERED))))
    (begin
      (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_UNAUTHORIZED))
      (ok (map-set merchants merchant (merge merchant-data { is-active: false })))
    )
  )
)

;; Emergency functions
(define-public (emergency-withdraw
    (amount uint)
    (recipient principal)
  )
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_UNAUTHORIZED))
    (unwrap! (as-contract (contract-call? SBTC_TOKEN_CONTRACT transfer amount tx-sender recipient none))
      (err ERR_INSUFFICIENT_AMOUNT)
    )
    (ok true)
  )
)