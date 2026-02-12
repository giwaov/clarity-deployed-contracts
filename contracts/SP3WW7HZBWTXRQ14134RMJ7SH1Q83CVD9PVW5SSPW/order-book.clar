;; Order Book DEX
;; Decentralized exchange with order book

(define-constant contract-owner tx-sender)
(define-data-var next-order-id uint u1)

(define-map orders
  uint
  {
    trader: principal,
    amount: uint,
    price: uint,
    order-type: (string-ascii 4),
    filled: bool
  }
)

(define-read-only (get-order (order-id uint))
  (map-get? orders order-id)
)

(define-public (place-order (amount uint) (price uint) (order-type (string-ascii 4)))
  (let ((order-id (var-get next-order-id)))
    (map-set orders order-id {
      trader: tx-sender,
      amount: amount,
      price: price,
      order-type: order-type,
      filled: false
    })
    (var-set next-order-id (+ order-id u1))
    (ok order-id)
  )
)

(define-public (fill-order (order-id uint))
  (let ((order (unwrap! (map-get? orders order-id) (err u100))))
    (asserts! (not (get filled order)) (err u101))
    (map-set orders order-id (merge order { filled: true }))
    (ok true)
  )
)
