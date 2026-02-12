;; Payment Processor Contract
;; Processes instant payments with platform fees

(define-constant contract-owner tx-sender)
(define-constant platform-fee-percentage u2) ;; 2% platform fee
(define-constant err-not-authorized (err u999))

(define-map payment-history
  { payment-id: uint }
  {
    sender: principal,
    recipient: principal,
    amount: uint,
    fee: uint,
    timestamp: uint,
    status: (string-ascii 20)
  }
)

(define-data-var payment-counter uint u0)
(define-data-var total-fees-collected uint u0)

;; Process payment
(define-public (send-payment (recipient principal) (amount uint) (memo (string-utf8 256)))
  (let
    (
      (fee (/ (* amount platform-fee-percentage) u100))
      (net-amount (- amount fee))
      (payment-id (+ (var-get payment-counter) u1))
    )
    ;; Validations
    (asserts! (> amount u0) (err u200)) ;; Amount must be positive
    (asserts! (not (is-eq tx-sender recipient)) (err u201)) ;; Cannot send to self
    (asserts! (> net-amount u0) (err u202)) ;; Net amount must be positive
    
    ;; Transfer to recipient (fee stays with sender as implicit cost)
    (try! (stx-transfer? net-amount tx-sender recipient))
    
    ;; Record payment
    (map-set payment-history
      { payment-id: payment-id }
      {
        sender: tx-sender,
        recipient: recipient,
        amount: amount,
        fee: fee,
        timestamp: stacks-block-height,
        status: "completed"
      }
    )
    
    ;; Update counters
    (var-set payment-counter payment-id)
    (var-set total-fees-collected (+ (var-get total-fees-collected) fee))
    
    (ok payment-id)
  )
)

;; Get payment details
(define-read-only (get-payment (payment-id uint))
  (map-get? payment-history { payment-id: payment-id })
)

;; Get total fees collected
(define-read-only (get-total-fees)
  (ok (var-get total-fees-collected))
)

;; Get user payment count
(define-read-only (get-user-payment-count (user principal))
  (ok u0) ;; Simplified - in production, maintain a counter
)
