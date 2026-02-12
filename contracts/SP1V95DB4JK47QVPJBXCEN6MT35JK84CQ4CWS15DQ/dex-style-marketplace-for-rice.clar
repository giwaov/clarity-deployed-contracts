(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-params (err u103))
(define-constant err-insufficient-liquidity (err u104))
(define-constant err-slippage-exceeded (err u105))

(define-map pools
  {pool-id: uint}
  {
    variety: (string-ascii 64),
    reserve-rice: uint,
    reserve-stx: uint,
    total-shares: uint,
    fee-rate: uint,
    active: bool
  }
)

(define-map liquidity-positions
  {pool-id: uint, provider: principal}
  {shares: uint}
)

(define-data-var pool-nonce uint u0)

(define-read-only (get-pool (pool-id uint))
  (map-get? pools {pool-id: pool-id})
)

(define-read-only (get-position (pool-id uint) (provider principal))
  (map-get? liquidity-positions {pool-id: pool-id, provider: provider})
)

(define-public (create-pool
  (variety (string-ascii 64))
  (initial-rice uint)
  (initial-stx uint)
  (fee-rate uint)
)
  (let ((pool-id (var-get pool-nonce)))
    (asserts! (> initial-rice u0) err-invalid-params)
    (asserts! (> initial-stx u0) err-invalid-params)
    (asserts! (<= fee-rate u10000) err-invalid-params)
    (map-set pools {pool-id: pool-id}
      {
        variety: variety,
        reserve-rice: initial-rice,
        reserve-stx: initial-stx,
        total-shares: initial-rice,
        fee-rate: fee-rate,
        active: true
      }
    )
    (map-set liquidity-positions {pool-id: pool-id, provider: tx-sender}
      {shares: initial-rice}
    )
    (var-set pool-nonce (+ pool-id u1))
    (ok pool-id)
  )
)

(define-public (add-liquidity
  (pool-id uint)
  (rice-amount uint)
  (stx-amount uint)
  (min-shares uint)
)
  (let (
    (pool (unwrap! (map-get? pools {pool-id: pool-id}) err-not-found))
    (current-position (default-to {shares: u0}
      (map-get? liquidity-positions {pool-id: pool-id, provider: tx-sender})))
    (shares (/ (* rice-amount (get total-shares pool)) (get reserve-rice pool)))
  )
    (asserts! (get active pool) err-unauthorized)
    (asserts! (>= shares min-shares) err-slippage-exceeded)
    (map-set pools {pool-id: pool-id}
      (merge pool {
        reserve-rice: (+ (get reserve-rice pool) rice-amount),
        reserve-stx: (+ (get reserve-stx pool) stx-amount),
        total-shares: (+ (get total-shares pool) shares)
      })
    )
    (ok (map-set liquidity-positions {pool-id: pool-id, provider: tx-sender}
      {shares: (+ (get shares current-position) shares)}
    ))
  )
)

(define-public (remove-liquidity
  (pool-id uint)
  (shares uint)
  (min-rice uint)
  (min-stx uint)
)
  (let (
    (pool (unwrap! (map-get? pools {pool-id: pool-id}) err-not-found))
    (position (unwrap! (map-get? liquidity-positions {pool-id: pool-id, provider: tx-sender}) err-not-found))
    (rice-amount (/ (* shares (get reserve-rice pool)) (get total-shares pool)))
    (stx-amount (/ (* shares (get reserve-stx pool)) (get total-shares pool)))
  )
    (asserts! (<= shares (get shares position)) err-insufficient-liquidity)
    (asserts! (>= rice-amount min-rice) err-slippage-exceeded)
    (asserts! (>= stx-amount min-stx) err-slippage-exceeded)
    (map-set pools {pool-id: pool-id}
      (merge pool {
        reserve-rice: (- (get reserve-rice pool) rice-amount),
        reserve-stx: (- (get reserve-stx pool) stx-amount),
        total-shares: (- (get total-shares pool) shares)
      })
    )
    (ok (map-set liquidity-positions {pool-id: pool-id, provider: tx-sender}
      {shares: (- (get shares position) shares)}
    ))
  )
)

(define-public (swap-rice-for-stx
  (pool-id uint)
  (rice-in uint)
  (min-stx-out uint)
)
  (let (
    (pool (unwrap! (map-get? pools {pool-id: pool-id}) err-not-found))
    (fee (/ (* rice-in (get fee-rate pool)) u10000))
    (rice-in-after-fee (- rice-in fee))
    (stx-out (/ (* rice-in-after-fee (get reserve-stx pool)) 
               (+ (get reserve-rice pool) rice-in-after-fee)))
  )
    (asserts! (get active pool) err-unauthorized)
    (asserts! (>= stx-out min-stx-out) err-slippage-exceeded)
    (ok (map-set pools {pool-id: pool-id}
      (merge pool {
        reserve-rice: (+ (get reserve-rice pool) rice-in),
        reserve-stx: (- (get reserve-stx pool) stx-out)
      })
    ))
  )
)

(define-public (swap-stx-for-rice
  (pool-id uint)
  (stx-in uint)
  (min-rice-out uint)
)
  (let (
    (pool (unwrap! (map-get? pools {pool-id: pool-id}) err-not-found))
    (fee (/ (* stx-in (get fee-rate pool)) u10000))
    (stx-in-after-fee (- stx-in fee))
    (rice-out (/ (* stx-in-after-fee (get reserve-rice pool)) 
                (+ (get reserve-stx pool) stx-in-after-fee)))
  )
    (asserts! (get active pool) err-unauthorized)
    (asserts! (>= rice-out min-rice-out) err-slippage-exceeded)
    (ok (map-set pools {pool-id: pool-id}
      (merge pool {
        reserve-rice: (- (get reserve-rice pool) rice-out),
        reserve-stx: (+ (get reserve-stx pool) stx-in)
      })
    ))
  )
)
