(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-pair-inactive (err u105))
(define-constant err-insufficient-liquidity (err u106))

(define-data-var pair-nonce uint u0)
(define-data-var order-nonce uint u0)

(define-map fx-pairs
  uint
  {
    base-currency: (string-ascii 10),
    quote-currency: (string-ascii 10),
    oracle-source: (buff 32),
    exchange-rate: uint,
    total-base-liquidity: uint,
    total-quote-liquidity: uint,
    active: bool,
    last-update: uint
  }
)

(define-map limit-orders
  uint
  {
    trader: principal,
    pair-id: uint,
    order-type: (string-ascii 10),
    base-amount: uint,
    quote-amount: uint,
    limit-price: uint,
    filled: bool,
    cancelled: bool,
    created-at: uint
  }
)

(define-map liquidity-positions
  {pair-id: uint, provider: principal}
  {
    base-provided: uint,
    quote-provided: uint,
    share-percentage: uint
  }
)

(define-map trader-orders principal (list 100 uint))
(define-map pair-orders uint (list 500 uint))

(define-public (create-fx-pair (base-currency (string-ascii 10)) (quote-currency (string-ascii 10)) (oracle-source (buff 32)) (initial-rate uint))
  (let
    (
      (pair-id (+ (var-get pair-nonce) u1))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> initial-rate u0) err-invalid-amount)
    (map-set fx-pairs pair-id
      {
        base-currency: base-currency,
        quote-currency: quote-currency,
        oracle-source: oracle-source,
        exchange-rate: initial-rate,
        total-base-liquidity: u0,
        total-quote-liquidity: u0,
        active: true,
        last-update: stacks-block-height
      }
    )
    (var-set pair-nonce pair-id)
    (ok pair-id)
  )
)

(define-public (add-liquidity (pair-id uint) (base-amount uint) (quote-amount uint))
  (let
    (
      (pair (unwrap! (map-get? fx-pairs pair-id) err-not-found))
      (position (default-to {base-provided: u0, quote-provided: u0, share-percentage: u0} (map-get? liquidity-positions {pair-id: pair-id, provider: tx-sender})))
    )
    (asserts! (get active pair) err-pair-inactive)
    (asserts! (> base-amount u0) err-invalid-amount)
    (asserts! (> quote-amount u0) err-invalid-amount)
    (try! (stx-transfer? (+ base-amount quote-amount) tx-sender (as-contract tx-sender)))
    (let
      (
        (new-base-total (+ (get total-base-liquidity pair) base-amount))
        (new-quote-total (+ (get total-quote-liquidity pair) quote-amount))
        (share-pct (if (> new-base-total u0) (/ (* base-amount u10000) new-base-total) u0))
      )
      (map-set liquidity-positions {pair-id: pair-id, provider: tx-sender}
        {
          base-provided: (+ (get base-provided position) base-amount),
          quote-provided: (+ (get quote-provided position) quote-amount),
          share-percentage: share-pct
        }
      )
      (map-set fx-pairs pair-id (merge pair {
        total-base-liquidity: new-base-total,
        total-quote-liquidity: new-quote-total
      }))
      (ok true)
    )
  )
)

(define-public (place-limit-order (pair-id uint) (order-type (string-ascii 10)) (base-amount uint) (limit-price uint))
  (let
    (
      (pair (unwrap! (map-get? fx-pairs pair-id) err-not-found))
      (order-id (+ (var-get order-nonce) u1))
      (quote-amount (/ (* base-amount limit-price) u10000))
    )
    (asserts! (get active pair) err-pair-inactive)
    (asserts! (> base-amount u0) err-invalid-amount)
    (asserts! (> limit-price u0) err-invalid-amount)
    (try! (stx-transfer? (if (is-eq order-type "buy") quote-amount base-amount) tx-sender (as-contract tx-sender)))
    (map-set limit-orders order-id
      {
        trader: tx-sender,
        pair-id: pair-id,
        order-type: order-type,
        base-amount: base-amount,
        quote-amount: quote-amount,
        limit-price: limit-price,
        filled: false,
        cancelled: false,
        created-at: stacks-block-height
      }
    )
    (map-set trader-orders tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? trader-orders tx-sender)) order-id) u100)))
    (map-set pair-orders pair-id
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? pair-orders pair-id)) order-id) u500)))
    (var-set order-nonce order-id)
    (ok order-id)
  )
)

(define-public (execute-market-swap (pair-id uint) (base-amount uint) (is-buy bool))
  (let
    (
      (pair (unwrap! (map-get? fx-pairs pair-id) err-not-found))
      (quote-amount (/ (* base-amount (get exchange-rate pair)) u10000))
    )
    (asserts! (get active pair) err-pair-inactive)
    (asserts! (> base-amount u0) err-invalid-amount)
    (if is-buy
      (begin
        (asserts! (>= (get total-base-liquidity pair) base-amount) err-insufficient-liquidity)
        (try! (stx-transfer? quote-amount tx-sender (as-contract tx-sender)))
        (try! (as-contract (stx-transfer? base-amount tx-sender tx-sender)))
        (map-set fx-pairs pair-id (merge pair {
          total-base-liquidity: (- (get total-base-liquidity pair) base-amount),
          total-quote-liquidity: (+ (get total-quote-liquidity pair) quote-amount)
        }))
      )
      (begin
        (asserts! (>= (get total-quote-liquidity pair) quote-amount) err-insufficient-liquidity)
        (try! (stx-transfer? base-amount tx-sender (as-contract tx-sender)))
        (try! (as-contract (stx-transfer? quote-amount tx-sender tx-sender)))
        (map-set fx-pairs pair-id (merge pair {
          total-base-liquidity: (+ (get total-base-liquidity pair) base-amount),
          total-quote-liquidity: (- (get total-quote-liquidity pair) quote-amount)
        }))
      )
    )
    (ok quote-amount)
  )
)

(define-public (update-exchange-rate (pair-id uint) (new-rate uint))
  (let
    (
      (pair (unwrap! (map-get? fx-pairs pair-id) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set fx-pairs pair-id (merge pair {
      exchange-rate: new-rate,
      last-update: stacks-block-height
    }))
    (ok true)
  )
)

(define-public (cancel-order (order-id uint))
  (let
    (
      (order (unwrap! (map-get? limit-orders order-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get trader order)) err-unauthorized)
    (asserts! (not (get filled order)) err-already-exists)
    (asserts! (not (get cancelled order)) err-already-exists)
    (let
      (
        (refund-amount (if (is-eq (get order-type order) "buy") (get quote-amount order) (get base-amount order)))
      )
      (try! (as-contract (stx-transfer? refund-amount tx-sender (get trader order))))
      (map-set limit-orders order-id (merge order {cancelled: true}))
      (ok true)
    )
  )
)

(define-read-only (get-fx-pair (pair-id uint))
  (ok (map-get? fx-pairs pair-id))
)

(define-read-only (get-order (order-id uint))
  (ok (map-get? limit-orders order-id))
)

(define-read-only (get-liquidity-position (pair-id uint) (provider principal))
  (ok (map-get? liquidity-positions {pair-id: pair-id, provider: provider}))
)

(define-read-only (get-trader-orders (trader principal))
  (ok (map-get? trader-orders trader))
)
