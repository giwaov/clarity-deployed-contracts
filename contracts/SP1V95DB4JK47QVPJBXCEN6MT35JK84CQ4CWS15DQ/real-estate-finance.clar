(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u104))
(define-constant err-property-financed (err u116))

(define-data-var property-nonce uint u0)

(define-map properties
  uint
  {
    owner: principal,
    lender: principal,
    property-value: uint,
    loan-amount: uint,
    down-payment: uint,
    interest-rate: uint,
    ltv: uint,
    monthly-payment: uint,
    outstanding: uint,
    financed: bool,
    term-blocks: uint,
    start-block: uint
  }
)

(define-map payments
  {property-id: uint, payment-id: uint}
  {
    amount: uint,
    block: uint,
    principal-portion: uint,
    interest-portion: uint
  }
)

(define-map payment-counter uint uint)
(define-map owner-properties principal (list 20 uint))

(define-public (register-property (value uint) (loan-amt uint) (down uint) (rate uint) (term uint))
  (let
    (
      (property-id (+ (var-get property-nonce) u1))
      (ltv-ratio (/ (* loan-amt u100) value))
    )
    (asserts! (> value u0) err-invalid-amount)
    (asserts! (is-eq (+ loan-amt down) value) err-invalid-amount)
    (map-set properties property-id {
      owner: tx-sender,
      lender: tx-sender,
      property-value: value,
      loan-amount: loan-amt,
      down-payment: down,
      interest-rate: rate,
      ltv: ltv-ratio,
      monthly-payment: u0,
      outstanding: loan-amt,
      financed: false,
      term-blocks: term,
      start-block: u0
    })
    (map-set payment-counter property-id u0)
    (map-set owner-properties tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? owner-properties tx-sender)) property-id) u20)))
    (var-set property-nonce property-id)
    (ok property-id)
  )
)

(define-public (finance-property (property-id uint) (lender principal))
  (let
    (
      (property (unwrap! (map-get? properties property-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get owner property)) err-unauthorized)
    (asserts! (not (get financed property)) err-property-financed)
    (try! (stx-transfer? (get loan-amount property) lender tx-sender))
    (map-set properties property-id (merge property {
      lender: lender,
      financed: true,
      start-block: stacks-block-height
    }))
    (ok true)
  )
)

(define-public (make-payment (property-id uint) (amount uint))
  (let
    (
      (property (unwrap! (map-get? properties property-id) err-not-found))
      (interest (calculate-interest property-id))
      (principal-portion (if (> amount interest) (- amount interest) u0))
      (new-outstanding (if (>= principal-portion (get outstanding property)) 
                          u0 
                          (- (get outstanding property) principal-portion)))
      (pid (+ (default-to u0 (map-get? payment-counter property-id)) u1))
    )
    (asserts! (is-eq tx-sender (get owner property)) err-unauthorized)
    (asserts! (get financed property) err-property-financed)
    (try! (stx-transfer? amount tx-sender (get lender property)))
    (map-set payments {property-id: property-id, payment-id: pid} {
      amount: amount,
      block: stacks-block-height,
      principal-portion: principal-portion,
      interest-portion: interest
    })
    (map-set payment-counter property-id pid)
    (map-set properties property-id (merge property {outstanding: new-outstanding}))
    (ok true)
  )
)

(define-public (refinance (property-id uint) (new-lender principal) (new-rate uint))
  (let
    (
      (property (unwrap! (map-get? properties property-id) err-not-found))
      (payoff (calculate-payoff property-id))
    )
    (asserts! (is-eq tx-sender (get owner property)) err-unauthorized)
    (try! (stx-transfer? payoff new-lender (get lender property)))
    (map-set properties property-id (merge property {
      lender: new-lender,
      interest-rate: new-rate,
      outstanding: payoff,
      start-block: stacks-block-height
    }))
    (ok true)
  )
)

(define-read-only (get-property (property-id uint))
  (ok (map-get? properties property-id))
)

(define-read-only (get-payment (property-id uint) (payment-id uint))
  (ok (map-get? payments {property-id: property-id, payment-id: payment-id}))
)

(define-read-only (get-owner-properties (owner principal))
  (ok (map-get? owner-properties owner))
)

(define-read-only (calculate-interest (property-id uint))
  (let
    (
      (property (unwrap-panic (map-get? properties property-id)))
      (outstanding (get outstanding property))
      (rate (get interest-rate property))
    )
    (/ (* outstanding rate) u120000)
  )
)

(define-read-only (calculate-payoff (property-id uint))
  (let
    (
      (property (unwrap-panic (map-get? properties property-id)))
      (outstanding (get outstanding property))
      (interest (calculate-interest property-id))
    )
    (+ outstanding interest)
  )
)

(define-read-only (get-equity (property-id uint))
  (let
    (
      (property (unwrap-panic (map-get? properties property-id)))
    )
    (ok (- (get property-value property) (get outstanding property)))
  )
)
