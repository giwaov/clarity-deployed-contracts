(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-insufficient-margin (err u105))
(define-constant err-position-liquidated (err u106))

(define-data-var market-nonce uint u0)
(define-data-var position-nonce uint u0)

(define-map perp-markets
  uint
  {
    market-name: (string-ascii 50),
    underlying-asset: (string-ascii 30),
    oracle-source: (buff 32),
    mark-price: uint,
    index-price: uint,
    funding-rate: int,
    total-long: uint,
    total-short: uint,
    active: bool
  }
)

(define-map perpetual-positions
  uint
  {
    trader: principal,
    market-id: uint,
    position-size: int,
    entry-price: uint,
    margin: uint,
    leverage: uint,
    liquidation-price: uint,
    unrealized-pnl: int,
    open: bool
  }
)

(define-map trader-positions principal (list 100 uint))
(define-map market-positions uint (list 500 uint))

(define-public (create-perp-market (market-name (string-ascii 50)) (underlying-asset (string-ascii 30)) (oracle-source (buff 32)) (initial-price uint))
  (let
    (
      (market-id (+ (var-get market-nonce) u1))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> initial-price u0) err-invalid-amount)
    (map-set perp-markets market-id
      {
        market-name: market-name,
        underlying-asset: underlying-asset,
        oracle-source: oracle-source,
        mark-price: initial-price,
        index-price: initial-price,
        funding-rate: 0,
        total-long: u0,
        total-short: u0,
        active: true
      }
    )
    (var-set market-nonce market-id)
    (ok market-id)
  )
)

(define-public (open-long-position (market-id uint) (size uint) (margin uint) (leverage uint))
  (let
    (
      (market (unwrap! (map-get? perp-markets market-id) err-not-found))
      (position-id (+ (var-get position-nonce) u1))
      (position-value (* size (get mark-price market)))
      (required-margin (/ position-value leverage))
    )
    (asserts! (get active market) err-not-found)
    (asserts! (>= margin required-margin) err-insufficient-margin)
    (asserts! (> size u0) err-invalid-amount)
    (asserts! (and (>= leverage u1) (<= leverage u50)) err-invalid-amount)
    (try! (stx-transfer? margin tx-sender (as-contract tx-sender)))
    (let
      (
        (liquidation-price (/ (* (get mark-price market) (- leverage u1)) leverage))
      )
      (map-set perpetual-positions position-id
        {
          trader: tx-sender,
          market-id: market-id,
          position-size: (to-int size),
          entry-price: (get mark-price market),
          margin: margin,
          leverage: leverage,
          liquidation-price: liquidation-price,
          unrealized-pnl: 0,
          open: true
        }
      )
      (map-set perp-markets market-id (merge market {
        total-long: (+ (get total-long market) size)
      }))
      (map-set trader-positions tx-sender
        (unwrap-panic (as-max-len? (append (default-to (list) (map-get? trader-positions tx-sender)) position-id) u100)))
      (map-set market-positions market-id
        (unwrap-panic (as-max-len? (append (default-to (list) (map-get? market-positions market-id)) position-id) u500)))
      (var-set position-nonce position-id)
      (ok position-id)
    )
  )
)

(define-public (open-short-position (market-id uint) (size uint) (margin uint) (leverage uint))
  (let
    (
      (market (unwrap! (map-get? perp-markets market-id) err-not-found))
      (position-id (+ (var-get position-nonce) u1))
      (position-value (* size (get mark-price market)))
      (required-margin (/ position-value leverage))
    )
    (asserts! (get active market) err-not-found)
    (asserts! (>= margin required-margin) err-insufficient-margin)
    (asserts! (> size u0) err-invalid-amount)
    (asserts! (and (>= leverage u1) (<= leverage u50)) err-invalid-amount)
    (try! (stx-transfer? margin tx-sender (as-contract tx-sender)))
    (let
      (
        (liquidation-price (/ (* (get mark-price market) (+ leverage u1)) leverage))
      )
      (map-set perpetual-positions position-id
        {
          trader: tx-sender,
          market-id: market-id,
          position-size: (to-int (* size u1000000)),
          entry-price: (get mark-price market),
          margin: margin,
          leverage: leverage,
          liquidation-price: liquidation-price,
          unrealized-pnl: 0,
          open: true
        }
      )
      (map-set perp-markets market-id (merge market {
        total-short: (+ (get total-short market) size)
      }))
      (map-set trader-positions tx-sender
        (unwrap-panic (as-max-len? (append (default-to (list) (map-get? trader-positions tx-sender)) position-id) u100)))
      (map-set market-positions market-id
        (unwrap-panic (as-max-len? (append (default-to (list) (map-get? market-positions market-id)) position-id) u500)))
      (var-set position-nonce position-id)
      (ok position-id)
    )
  )
)

(define-public (close-position (position-id uint))
  (let
    (
      (position (unwrap! (map-get? perpetual-positions position-id) err-not-found))
      (market (unwrap! (map-get? perp-markets (get market-id position)) err-not-found))
    )
    (asserts! (is-eq tx-sender (get trader position)) err-unauthorized)
    (asserts! (get open position) err-already-exists)
    (let
      (
        (is-long (> (get position-size position) 0))
        (size (if is-long (to-uint (get position-size position)) (to-uint (- 0 (get position-size position)))))
        (pnl-value (if is-long
          (to-int (- (* size (get mark-price market)) (* size (get entry-price position))))
          (to-int (- (* size (get entry-price position)) (* size (get mark-price market))))))
        (final-balance (to-uint (+ (to-int (get margin position)) pnl-value)))
      )
      (if (> final-balance u0)
        (try! (as-contract (stx-transfer? final-balance tx-sender (get trader position))))
        true
      )
      (map-set perpetual-positions position-id (merge position {
        open: false,
        unrealized-pnl: pnl-value
      }))
      (map-set perp-markets (get market-id position) (merge market {
        total-long: (if is-long (- (get total-long market) size) (get total-long market)),
        total-short: (if is-long (get total-short market) (- (get total-short market) size))
      }))
      (ok final-balance)
    )
  )
)

(define-public (update-mark-price (market-id uint) (new-price uint))
  (let
    (
      (market (unwrap! (map-get? perp-markets market-id) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set perp-markets market-id (merge market {mark-price: new-price}))
    (ok true)
  )
)

(define-read-only (get-perp-market (market-id uint))
  (ok (map-get? perp-markets market-id))
)

(define-read-only (get-position (position-id uint))
  (ok (map-get? perpetual-positions position-id))
)

(define-read-only (get-trader-positions (trader principal))
  (ok (map-get? trader-positions trader))
)

(define-read-only (get-market-positions (market-id uint))
  (ok (map-get? market-positions market-id))
)
