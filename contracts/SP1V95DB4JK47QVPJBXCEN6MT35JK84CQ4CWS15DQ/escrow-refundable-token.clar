(define-fungible-token escrow-token)

(define-data-var seller-contract principal tx-sender)
(define-data-var buyer-contract principal tx-sender)
(define-data-var escrow-state (string-ascii 20) "init")
(define-data-var seller-amount uint u0)
(define-data-var buyer-amount uint u0)
(define-data-var seller-address principal tx-sender)
(define-data-var buyer-address principal tx-sender)

(define-constant err-invalid-state (err u200))
(define-constant err-unauthorized (err u201))
(define-constant err-invalid-contract (err u202))
(define-constant err-insufficient-funds (err u203))

(define-read-only (get-escrow-state)
  (ok (var-get escrow-state)))

(define-read-only (get-seller-balance)
  (ok (var-get seller-amount)))

(define-read-only (get-buyer-balance)
  (ok (var-get buyer-amount)))

(define-public (init-escrow (seller principal) (buyer principal))
  (begin
    (asserts! (is-eq (var-get escrow-state) "init") err-invalid-state)
    (var-set seller-contract seller)
    (var-set buyer-contract buyer)
    (ok true)))

(define-public (escrow-fund (to principal) (value uint))
  (begin
    (if (is-eq contract-caller (var-get seller-contract))
      (begin
        (asserts! (is-eq (var-get escrow-state) "running") err-invalid-state)
        (var-set seller-address to)
        (var-set seller-amount value)
        (var-set escrow-state "success")
        (ok true))
      (if (is-eq contract-caller (var-get buyer-contract))
        (begin
          (asserts! (is-eq (var-get escrow-state) "init") err-invalid-state)
          (var-set buyer-address to)
          (var-set buyer-amount value)
          (var-set escrow-state "running")
          (ok true))
        err-invalid-contract))))

(define-public (escrow-refund (from principal) (value uint))
  (begin
    (asserts! (is-eq (var-get escrow-state) "running") err-invalid-state)
    (asserts! (is-eq contract-caller (var-get buyer-contract)) err-invalid-contract)
    (asserts! (is-eq (var-get buyer-address) from) err-unauthorized)
    (asserts! (>= (var-get buyer-amount) value) err-insufficient-funds)
    (var-set buyer-amount (- (var-get buyer-amount) value))
    (ok true)))

(define-public (escrow-withdraw)
  (let ((common (if (< (var-get buyer-amount) (var-get seller-amount))
                   (var-get buyer-amount)
                   (var-get seller-amount))))
    (asserts! (is-eq (var-get escrow-state) "success") err-invalid-state)
    (if (> common u0)
      (begin
        (var-set buyer-amount (- (var-get buyer-amount) common))
        (var-set seller-amount (- (var-get seller-amount) common))
        (var-set escrow-state "closed")
        (ok true))
      (begin
        (var-set escrow-state "closed")
        (ok true)))))
