;; title: kaluuba-payments
;; version: 1.0.0
;; summary: Payment processing contract for Kaluuba
;; description: Handles direct payments between users using usernames

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-invalid-amount (err u200))
(define-constant err-payment-failed (err u201))
(define-constant err-user-not-found (err u202))
(define-constant err-self-payment (err u203))
(define-constant err-user-inactive (err u204))

;; Data Variables
(define-data-var total-payments uint u0)
(define-data-var total-volume uint u0)

;; Data Maps
(define-map payments
  { payment-id: uint }
  {
    from: principal,
    to: principal,
    amount: uint,
    timestamp: uint,
    memo: (optional (string-utf8 256))
  }
)

(define-map user-payment-count
  { user: principal }
  { sent: uint, received: uint }
)

;; Private Functions
(define-private (increment-payment-count (sender principal) (recipient principal))
  (let
    (
      (sender-stats (default-to { sent: u0, received: u0 } 
        (map-get? user-payment-count { user: sender })))
      (recipient-stats (default-to { sent: u0, received: u0 } 
        (map-get? user-payment-count { user: recipient })))
    )
    (map-set user-payment-count
      { user: sender }
      { sent: (+ (get sent sender-stats) u1), received: (get received sender-stats) }
    )
    (map-set user-payment-count
      { user: recipient }
      { sent: (get sent recipient-stats), received: (+ (get received recipient-stats) u1) }
    )
  )
)

;; Read-only Functions
(define-read-only (get-payment (payment-id uint))
  (map-get? payments { payment-id: payment-id })
)

(define-read-only (get-total-payments)
  (ok (var-get total-payments))
)

(define-read-only (get-total-volume)
  (ok (var-get total-volume))
)

(define-read-only (get-user-stats (user principal))
  (ok (default-to { sent: u0, received: u0 } 
    (map-get? user-payment-count { user: user })))
)

;; Public Functions
(define-public (send-payment-to-username 
  (recipient-username (string-ascii 20))
  (amount uint)
  (memo (optional (string-utf8 256))))
  (let
    (
      (sender tx-sender)
      (recipient-address (unwrap! 
        (contract-call? .kaluuba-users get-user-address recipient-username)
        err-user-not-found))
      (payment-id (var-get total-payments))
    )
    ;; Validate amount
    (asserts! (> amount u0) err-invalid-amount)
    
    ;; Prevent self-payment
    (asserts! (not (is-eq sender recipient-address)) err-self-payment)
    
    ;; Transfer STX
    (try! (stx-transfer? amount sender recipient-address))
    
    ;; Record payment
    (map-set payments
      { payment-id: payment-id }
      {
        from: sender,
        to: recipient-address,
        amount: amount,
        timestamp: stacks-block-height,
        memo: memo
      }
    )
    
    ;; Update statistics
    (increment-payment-count sender recipient-address)
    (var-set total-payments (+ payment-id u1))
    (var-set total-volume (+ (var-get total-volume) amount))
    
    (ok payment-id)
  )
)

(define-public (send-payment-to-address
  (recipient principal)
  (amount uint)
  (memo (optional (string-utf8 256))))
  (let
    (
      (sender tx-sender)
      (payment-id (var-get total-payments))
    )
    ;; Validate amount
    (asserts! (> amount u0) err-invalid-amount)
    
    ;; Prevent self-payment
    (asserts! (not (is-eq sender recipient)) err-self-payment)
    
    ;; Transfer STX
    (try! (stx-transfer? amount sender recipient))
    
    ;; Record payment
    (map-set payments
      { payment-id: payment-id }
      {
        from: sender,
        to: recipient,
        amount: amount,
        timestamp: stacks-block-height,
        memo: memo
      }
    )
    
    ;; Update statistics
    (increment-payment-count sender recipient)
    (var-set total-payments (+ payment-id u1))
    (var-set total-volume (+ (var-get total-volume) amount))
    
    (ok payment-id)
  )
)
