;; title: trustbill
;; version: 1.0.0
;; summary: A simple platform on Stacks for paying bills like airtime, data subscription, etc.
;; description: TrustBill allows users to pay various bills using STX tokens on the Stacks blockchain. Supports multiple bill types including airtime, data subscription, and more.

;; traits
(define-trait bill-provider-trait
  (
    ;; Process a bill payment and return success status
    (process-payment (uint uint principal) (response bool uint))
  )
)

;; token definitions
;; Uses native STX for payments

;; constants
(define-constant ERR-UNAUTHORIZED u1)
(define-constant ERR-INVALID-AMOUNT u2)
(define-constant ERR-BILL-NOT-FOUND u4)
(define-constant ERR-PAYMENT-FAILED u6)

;; bill types
;; These constants define the valid bill type values used in create-bill-payment
;; BILL-TYPE-UTILITY and BILL-TYPE-OTHER are valid but passed as parameters (u3, u4)
(define-constant BILL-TYPE-AIRTIME u1)
(define-constant BILL-TYPE-DATA u2)
(define-constant BILL-TYPE-UTILITY u3) ;; Used as parameter value u3 in create-bill-payment
(define-constant BILL-TYPE-OTHER u4) ;; Used as parameter value u4 in create-bill-payment

;; data vars
;; Admin will be set by deployer. Using deployer address as default - must be set on first deploy.
(define-data-var admin principal tx-sender)
(define-data-var service-fee-percentage uint u5) ;; 5% service fee

;; data maps
;; Bill payment record
(define-map bill-payments
  { id: uint }
  {
    payer: principal,
    bill-type: uint,
    amount: uint,
    recipient: (optional (string-ascii 100)),
    phone-number: (optional (string-ascii 100)),
    timestamp: uint,
    status: (string-ascii 20)
  }
)

;; Payment counter for unique IDs
(define-data-var payment-counter uint u0)

;; Provider registry - maps principal to bill type
(define-map provider-registry
  { provider: principal, bill-type: uint }
  bool
)

;; public functions

;; Initialize a bill payment for airtime
;; @param recipient: Phone number or recipient identifier
;; @param amount: Amount in micro-STX
;; Returns payment ID
(define-public (pay-airtime (recipient (string-ascii 100)) (amount uint))
  (begin
    (asserts! (> amount u0) (err ERR-INVALID-AMOUNT))
    (let
      (
        (payment-id (+ (var-get payment-counter) u1))
      )
      (begin
        (var-set payment-counter payment-id)
        (map-set bill-payments
          { id: payment-id }
          {
            payer: tx-sender,
            bill-type: BILL-TYPE-AIRTIME,
            amount: amount,
            recipient: (some recipient),
            phone-number: (some recipient),
            timestamp: payment-id,
            status: "pending"
          }
        )
        (ok payment-id)
      )
    )
  )
)

;; Initialize a bill payment for data subscription
;; @param recipient: Phone number or account identifier
;; @param amount: Amount in micro-STX
;; Returns payment ID
(define-public (pay-data-subscription (recipient (string-ascii 100)) (amount uint))
  (begin
    (asserts! (> amount u0) (err ERR-INVALID-AMOUNT))
    (let
      (
        (payment-id (+ (var-get payment-counter) u1))
      )
      (begin
        (var-set payment-counter payment-id)
        (map-set bill-payments
          { id: payment-id }
          {
            payer: tx-sender,
            bill-type: BILL-TYPE-DATA,
            amount: amount,
            recipient: (some recipient),
            phone-number: (some recipient),
            timestamp: payment-id,
            status: "pending"
          }
        )
        (ok payment-id)
      )
    )
  )
)

;; Process a bill payment with STX
;; @param payment-id: The payment ID to process
;; This function transfers STX from the caller to the contract and processes the payment
(define-public (process-payment (payment-id uint))
  (let
    (
      (payment (map-get? bill-payments { id: payment-id }))
    )
    (begin
      (asserts! (is-some payment) (err ERR-BILL-NOT-FOUND))
      (let
        (
          (bill-data (unwrap! payment (err ERR-BILL-NOT-FOUND)))
        )
        (begin
          (asserts! (is-eq (get status bill-data) "pending") (err ERR-PAYMENT-FAILED))
          (asserts! (is-eq tx-sender (get payer bill-data)) (err ERR-UNAUTHORIZED))
          (try! (stx-transfer?
            (get amount bill-data)
            tx-sender
            (var-get admin)
          ))
          ;; Update payment status to completed
          (map-set bill-payments
            { id: payment-id }
            {
              payer: (get payer bill-data),
              bill-type: (get bill-type bill-data),
              amount: (get amount bill-data),
              recipient: (get recipient bill-data),
              phone-number: (get phone-number bill-data),
              timestamp: (get timestamp bill-data),
              status: "completed"
            }
          )
          (ok true)
        )
      )
    )
  )
)

;; Create a custom bill payment
;; @param bill-type: Type of bill (1=airtime, 2=data, 3=utility, 4=other)
;; @param recipient: Recipient identifier
;; @param amount: Amount in micro-STX
(define-public (create-bill-payment
    (bill-type uint)
    (recipient (string-ascii 100))
    (amount uint)
  )
  (begin
    (asserts! (>= bill-type u1) (err ERR-INVALID-AMOUNT))
    (asserts! (<= bill-type u4) (err ERR-INVALID-AMOUNT))
    (asserts! (> amount u0) (err ERR-INVALID-AMOUNT))
    (let
      (
        (payment-id (+ (var-get payment-counter) u1))
      )
      (begin
        (var-set payment-counter payment-id)
        (map-set bill-payments
          { id: payment-id }
          {
            payer: tx-sender,
            bill-type: bill-type,
            amount: amount,
            recipient: (some recipient),
            phone-number: none,
            timestamp: payment-id,
            status: "pending"
          }
        )
        (ok payment-id)
      )
    )
  )
)

;; Admin function to update service fee
;; @param new-fee: New service fee percentage (0-100)
(define-public (set-service-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR-UNAUTHORIZED))
    (asserts! (<= new-fee u100) (err ERR-INVALID-AMOUNT))
    (var-set service-fee-percentage new-fee)
    (ok true)
  )
)

;; Admin function to register a provider
;; @param provider: Principal address of the provider
;; @param bill-type: Type of bill this provider handles
(define-public (register-provider (provider principal) (bill-type uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR-UNAUTHORIZED))
    (map-set provider-registry
      { provider: provider, bill-type: bill-type }
      true
    )
    (ok true)
  )
)

;; Admin function to update admin
;; @param new-admin: New admin principal
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR-UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)

;; read only functions

;; Get payment details by ID
;; @param payment-id: The payment ID to query
(define-read-only (get-payment (payment-id uint))
  (map-get? bill-payments { id: payment-id })
)

;; Get payment counter (total number of payments)
(define-read-only (get-payment-counter)
  (var-get payment-counter)
)

;; Get current admin
(define-read-only (get-admin)
  (var-get admin)
)

;; Get current service fee percentage
(define-read-only (get-service-fee)
  (var-get service-fee-percentage)
)

;; Check if a provider is registered for a bill type
;; @param provider: Provider principal
;; @param bill-type: Bill type to check
(define-read-only (is-provider-registered (provider principal) (bill-type uint))
  (default-to false (map-get? provider-registry { provider: provider, bill-type: bill-type }))
)

;; private functions
;;