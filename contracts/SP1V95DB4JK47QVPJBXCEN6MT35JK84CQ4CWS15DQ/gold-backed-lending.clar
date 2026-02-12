(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-collateral (err u102))
(define-constant err-invalid-amount (err u103))

(define-map gold-reserves
  principal
  {
    grams: uint,
    purity: uint,
    vault-location: (string-ascii 128),
    verified: bool
  })

(define-map gold-backed-loans
  uint
  {
    borrower: principal,
    collateral-grams: uint,
    loan-amount: uint,
    interest-rate: uint,
    gold-price-at-loan: uint,
    maturity-block: uint,
    repaid: bool
  })

(define-data-var next-loan-id uint u0)
(define-data-var current-gold-price uint u60000000)

(define-read-only (get-gold-reserve (owner principal))
  (ok (map-get? gold-reserves owner)))

(define-read-only (get-loan (loan-id uint))
  (ok (map-get? gold-backed-loans loan-id)))

(define-read-only (get-gold-price)
  (ok (var-get current-gold-price)))

(define-public (deposit-gold (grams uint) (purity uint) (vault (string-ascii 128)))
  (begin
    (map-set gold-reserves tx-sender
      {grams: grams, purity: purity, vault-location: vault, verified: false})
    (ok true)))

(define-public (verify-gold (owner principal))
  (let ((reserve (unwrap! (map-get? gold-reserves owner) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set gold-reserves owner (merge reserve {verified: true})))))

(define-public (update-gold-price (new-price uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (var-set current-gold-price new-price))))

(define-public (borrow-against-gold (collateral-grams uint) (loan-amount uint) (rate uint) (duration uint))
  (let ((reserve (unwrap! (map-get? gold-reserves tx-sender) err-not-found))
        (collateral-value (/ (* collateral-grams (var-get current-gold-price)) u31103))
        (ltv (/ (* loan-amount u100) collateral-value))
        (loan-id (var-get next-loan-id)))
    (asserts! (get verified reserve) err-not-found)
    (asserts! (>= (get grams reserve) collateral-grams) err-insufficient-collateral)
    (asserts! (<= ltv u70) err-insufficient-collateral)
    (try! (stx-transfer? loan-amount tx-sender (as-contract tx-sender)))
    (map-set gold-backed-loans loan-id
      {borrower: tx-sender, collateral-grams: collateral-grams, loan-amount: loan-amount,
       interest-rate: rate, gold-price-at-loan: (var-get current-gold-price),
       maturity-block: (+ stacks-block-height duration), repaid: false})
    (var-set next-loan-id (+ loan-id u1))
    (ok loan-id)))

(define-public (repay-loan (loan-id uint))
  (let ((loan (unwrap! (map-get? gold-backed-loans loan-id) err-not-found))
        (interest (/ (* (get loan-amount loan) (get interest-rate loan)) u10000))
        (total (+ (get loan-amount loan) interest)))
    (asserts! (is-eq tx-sender (get borrower loan)) err-owner-only)
    (asserts! (not (get repaid loan)) err-invalid-amount)
    (try! (stx-transfer? total tx-sender (as-contract tx-sender)))
    (ok (map-set gold-backed-loans loan-id (merge loan {repaid: true})))))
