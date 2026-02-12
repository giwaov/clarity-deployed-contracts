(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-BALANCE (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-ORDER-NOT-FOUND (err u103))
(define-constant ERR-SETTLEMENT-FAILED (err u104))

(define-map tokenized-stocks
  { stock-id: (string-ascii 20) }
  {
    company-name: (string-ascii 100),
    ticker: (string-ascii 10),
    total-supply: uint,
    issuer: principal
  }
)

(define-map stock-balances
  { stock-id: (string-ascii 20), holder: principal }
  uint
)

(define-map trade-orders
  { order-id: uint }
  {
    stock-id: (string-ascii 20),
    seller: principal,
    buyer: principal,
    quantity: uint,
    price-per-share: uint,
    total-amount: uint,
    settled: bool,
    created-at: uint
  }
)

(define-data-var order-nonce uint u0)

(define-public (issue-stock
  (stock-id (string-ascii 20))
  (company-name (string-ascii 100))
  (ticker (string-ascii 10))
  (initial-supply uint)
)
  (begin
    (map-set tokenized-stocks
      { stock-id: stock-id }
      {
        company-name: company-name,
        ticker: ticker,
        total-supply: initial-supply,
        issuer: tx-sender
      }
    )
    (ok (map-set stock-balances { stock-id: stock-id, holder: tx-sender } initial-supply))
  )
)

(define-public (create-trade-order
  (stock-id (string-ascii 20))
  (buyer principal)
  (quantity uint)
  (price uint)
)
  (let (
    (order-id (var-get order-nonce))
    (total (/ (* quantity price) u100))
    (seller-balance (default-to u0 (map-get? stock-balances { stock-id: stock-id, holder: tx-sender })))
  )
    (asserts! (>= seller-balance quantity) ERR-INSUFFICIENT-BALANCE)
    (map-set trade-orders
      { order-id: order-id }
      {
        stock-id: stock-id,
        seller: tx-sender,
        buyer: buyer,
        quantity: quantity,
        price-per-share: price,
        total-amount: total,
        settled: false,
        created-at: stacks-block-height
      }
    )
    (var-set order-nonce (+ order-id u1))
    (ok order-id)
  )
)

(define-public (settle-trade (order-id uint))
  (let (
    (order (unwrap! (map-get? trade-orders { order-id: order-id }) ERR-ORDER-NOT-FOUND))
    (seller-balance (default-to u0 (map-get? stock-balances { stock-id: (get stock-id order), holder: (get seller order) })))
    (buyer-balance (default-to u0 (map-get? stock-balances { stock-id: (get stock-id order), holder: (get buyer order) })))
  )
    (asserts! (not (get settled order)) ERR-SETTLEMENT-FAILED)
    (asserts! (>= seller-balance (get quantity order)) ERR-INSUFFICIENT-BALANCE)
    (map-set stock-balances
      { stock-id: (get stock-id order), holder: (get seller order) }
      (- seller-balance (get quantity order))
    )
    (map-set stock-balances
      { stock-id: (get stock-id order), holder: (get buyer order) }
      (+ buyer-balance (get quantity order))
    )
    (ok (map-set trade-orders
      { order-id: order-id }
      (merge order { settled: true })
    ))
  )
)

(define-read-only (get-stock-info (stock-id (string-ascii 20)))
  (map-get? tokenized-stocks { stock-id: stock-id })
)

(define-read-only (get-balance (stock-id (string-ascii 20)) (holder principal))
  (ok (default-to u0 (map-get? stock-balances { stock-id: stock-id, holder: holder })))
)

(define-read-only (get-order (order-id uint))
  (map-get? trade-orders { order-id: order-id })
)

(define-public (transfer-stock (stock-id (string-ascii 20)) (amount uint) (recipient principal))
  (let (
    (sender-balance (default-to u0 (map-get? stock-balances { stock-id: stock-id, holder: tx-sender })))
    (recipient-balance (default-to u0 (map-get? stock-balances { stock-id: stock-id, holder: recipient })))
  )
    (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
    (map-set stock-balances { stock-id: stock-id, holder: tx-sender } (- sender-balance amount))
    (ok (map-set stock-balances { stock-id: stock-id, holder: recipient } (+ recipient-balance amount)))
  )
)
