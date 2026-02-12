(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-loan-active (err u103))

(define-map loans
  uint
  {
    borrower: principal,
    lender: principal,
    principal-amount: uint,
    interest-rate: uint,
    duration-blocks: uint,
    start-block: uint,
    repaid: bool
  })

(define-map liquidity-pool principal uint)

(define-data-var next-loan-id uint u0)
(define-data-var total-liquidity uint u0)

(define-read-only (get-loan (loan-id uint))
  (ok (map-get? loans loan-id)))

(define-read-only (get-liquidity (provider principal))
  (ok (default-to u0 (map-get? liquidity-pool provider))))

(define-public (provide-liquidity (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set liquidity-pool tx-sender
      (+ (default-to u0 (map-get? liquidity-pool tx-sender)) amount))
    (var-set total-liquidity (+ (var-get total-liquidity) amount))
    (ok true)))

(define-public (withdraw-liquidity (amount uint))
  (let ((balance (default-to u0 (map-get? liquidity-pool tx-sender))))
    (asserts! (>= balance amount) err-insufficient-balance)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set liquidity-pool tx-sender (- balance amount))
    (var-set total-liquidity (- (var-get total-liquidity) amount))
    (ok true)))

(define-public (request-loan (amount uint) (rate uint) (duration uint))
  (let ((loan-id (var-get next-loan-id)))
    (asserts! (<= amount (var-get total-liquidity)) err-insufficient-balance)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set loans loan-id
      {borrower: tx-sender, lender: contract-owner, principal-amount: amount,
       interest-rate: rate, duration-blocks: duration, start-block: stacks-block-height, repaid: false})
    (var-set next-loan-id (+ loan-id u1))
    (var-set total-liquidity (- (var-get total-liquidity) amount))
    (ok loan-id)))

(define-public (repay-loan (loan-id uint))
  (let ((loan (unwrap! (map-get? loans loan-id) err-not-found))
        (interest (/ (* (get principal-amount loan) (get interest-rate loan)) u10000))
        (total-repayment (+ (get principal-amount loan) interest)))
    (asserts! (is-eq tx-sender (get borrower loan)) err-owner-only)
    (asserts! (not (get repaid loan)) err-loan-active)
    (try! (stx-transfer? total-repayment tx-sender (as-contract tx-sender)))
    (map-set loans loan-id (merge loan {repaid: true}))
    (var-set total-liquidity (+ (var-get total-liquidity) total-repayment))
    (ok true)))
