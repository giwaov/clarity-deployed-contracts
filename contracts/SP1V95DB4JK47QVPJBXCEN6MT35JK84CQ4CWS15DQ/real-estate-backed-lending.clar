(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-collateral (err u102))
(define-constant err-loan-active (err u103))

(define-map real-estate-properties
  uint
  {
    owner: principal,
    valuation: uint,
    property-address: (string-ascii 256),
    verified: bool
  })

(define-map collateralized-loans
  uint
  {
    borrower: principal,
    property-id: uint,
    loan-amount: uint,
    interest-rate: uint,
    ltv-ratio: uint,
    maturity-block: uint,
    repaid: bool
  })

(define-data-var next-property-id uint u0)
(define-data-var next-loan-id uint u0)

(define-read-only (get-property (property-id uint))
  (ok (map-get? real-estate-properties property-id)))

(define-read-only (get-loan (loan-id uint))
  (ok (map-get? collateralized-loans loan-id)))

(define-public (register-property (valuation uint) (address (string-ascii 256)))
  (let ((property-id (var-get next-property-id)))
    (map-set real-estate-properties property-id
      {owner: tx-sender, valuation: valuation, property-address: address, verified: false})
    (var-set next-property-id (+ property-id u1))
    (ok property-id)))

(define-public (verify-property (property-id uint))
  (let ((property (unwrap! (map-get? real-estate-properties property-id) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set real-estate-properties property-id (merge property {verified: true})))))

(define-public (borrow-against-property (property-id uint) (loan-amount uint) (rate uint) (duration uint))
  (let ((property (unwrap! (map-get? real-estate-properties property-id) err-not-found))
        (ltv (/ (* loan-amount u100) (get valuation property)))
        (loan-id (var-get next-loan-id)))
    (asserts! (get verified property) err-not-found)
    (asserts! (is-eq tx-sender (get owner property)) err-owner-only)
    (asserts! (<= ltv u75) err-insufficient-collateral)
    (try! (stx-transfer? loan-amount tx-sender (as-contract tx-sender)))
    (map-set collateralized-loans loan-id
      {borrower: tx-sender, property-id: property-id, loan-amount: loan-amount,
       interest-rate: rate, ltv-ratio: ltv, maturity-block: (+ stacks-block-height duration), repaid: false})
    (var-set next-loan-id (+ loan-id u1))
    (ok loan-id)))

(define-public (repay-loan (loan-id uint))
  (let ((loan (unwrap! (map-get? collateralized-loans loan-id) err-not-found))
        (interest (/ (* (get loan-amount loan) (get interest-rate loan)) u10000))
        (total (+ (get loan-amount loan) interest)))
    (asserts! (is-eq tx-sender (get borrower loan)) err-owner-only)
    (asserts! (not (get repaid loan)) err-loan-active)
    (try! (stx-transfer? total tx-sender (as-contract tx-sender)))
    (ok (map-set collateralized-loans loan-id (merge loan {repaid: true})))))
