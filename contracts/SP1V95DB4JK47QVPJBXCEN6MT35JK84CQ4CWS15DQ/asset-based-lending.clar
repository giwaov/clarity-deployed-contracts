(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u104))
(define-constant err-insufficient-collateral (err u110))
(define-constant err-loan-active (err u109))

(define-data-var facility-nonce uint u0)

(define-map facilities
  uint
  {
    borrower: principal,
    lender: principal,
    credit-limit: uint,
    drawn-amount: uint,
    collateral-type: (string-ascii 30),
    collateral-value: uint,
    advance-rate: uint,
    interest-rate: uint,
    active: bool,
    setup-block: uint
  }
)

(define-map drawdowns
  {facility-id: uint, draw-id: uint}
  {
    amount: uint,
    block: uint,
    repaid: bool
  }
)

(define-map draw-counter uint uint)
(define-map borrower-facilities principal (list 30 uint))
(define-map lender-facilities principal (list 30 uint))

(define-public (setup-facility (lender principal) (limit uint) (collateral-type (string-ascii 30)) 
                                (collateral-val uint) (advance uint) (rate uint))
  (let
    (
      (facility-id (+ (var-get facility-nonce) u1))
      (max-advance (/ (* collateral-val advance) u100))
    )
    (asserts! (> limit u0) err-invalid-amount)
    (asserts! (<= limit max-advance) err-insufficient-collateral)
    (map-set facilities facility-id {
      borrower: tx-sender,
      lender: lender,
      credit-limit: limit,
      drawn-amount: u0,
      collateral-type: collateral-type,
      collateral-value: collateral-val,
      advance-rate: advance,
      interest-rate: rate,
      active: true,
      setup-block: stacks-block-height
    })
    (map-set draw-counter facility-id u0)
    (map-set borrower-facilities tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? borrower-facilities tx-sender)) facility-id) u30)))
    (map-set lender-facilities lender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? lender-facilities lender)) facility-id) u30)))
    (var-set facility-nonce facility-id)
    (ok facility-id)
  )
)

(define-public (draw-funds (facility-id uint) (amount uint))
  (let
    (
      (facility (unwrap! (map-get? facilities facility-id) err-not-found))
      (new-drawn (+ (get drawn-amount facility) amount))
      (draw-id (+ (default-to u0 (map-get? draw-counter facility-id)) u1))
    )
    (asserts! (is-eq tx-sender (get borrower facility)) err-unauthorized)
    (asserts! (get active facility) err-loan-active)
    (asserts! (<= new-drawn (get credit-limit facility)) err-invalid-amount)
    (try! (stx-transfer? amount (get lender facility) tx-sender))
    (map-set drawdowns {facility-id: facility-id, draw-id: draw-id} {
      amount: amount,
      block: stacks-block-height,
      repaid: false
    })
    (map-set draw-counter facility-id draw-id)
    (map-set facilities facility-id (merge facility {drawn-amount: new-drawn}))
    (ok draw-id)
  )
)

(define-public (repay-drawdown (facility-id uint) (draw-id uint) (amount uint))
  (let
    (
      (facility (unwrap! (map-get? facilities facility-id) err-not-found))
      (drawdown (unwrap! (map-get? drawdowns {facility-id: facility-id, draw-id: draw-id}) err-not-found))
      (new-drawn (- (get drawn-amount facility) amount))
    )
    (asserts! (is-eq tx-sender (get borrower facility)) err-unauthorized)
    (try! (stx-transfer? amount tx-sender (get lender facility)))
    (map-set drawdowns {facility-id: facility-id, draw-id: draw-id}
      (merge drawdown {repaid: (>= amount (get amount drawdown))}))
    (map-set facilities facility-id (merge facility {drawn-amount: new-drawn}))
    (ok true)
  )
)

(define-public (update-collateral (facility-id uint) (new-value uint))
  (let
    (
      (facility (unwrap! (map-get? facilities facility-id) err-not-found))
      (new-limit (/ (* new-value (get advance-rate facility)) u100))
    )
    (asserts! (is-eq tx-sender (get borrower facility)) err-unauthorized)
    (map-set facilities facility-id (merge facility {
      collateral-value: new-value,
      credit-limit: new-limit
    }))
    (ok new-limit)
  )
)

(define-read-only (get-facility (facility-id uint))
  (ok (map-get? facilities facility-id))
)

(define-read-only (get-drawdown (facility-id uint) (draw-id uint))
  (ok (map-get? drawdowns {facility-id: facility-id, draw-id: draw-id}))
)

(define-read-only (get-borrower-facilities (borrower principal))
  (ok (map-get? borrower-facilities borrower))
)

(define-read-only (get-available-credit (facility-id uint))
  (let
    (
      (facility (unwrap-panic (map-get? facilities facility-id)))
    )
    (ok (- (get credit-limit facility) (get drawn-amount facility)))
  )
)

(define-read-only (calculate-interest (facility-id uint))
  (let
    (
      (facility (unwrap-panic (map-get? facilities facility-id)))
      (drawn (get drawn-amount facility))
      (rate (get interest-rate facility))
      (elapsed (- stacks-block-height (get setup-block facility)))
    )
    (/ (* drawn (* rate elapsed)) u10000000)
  )
)
