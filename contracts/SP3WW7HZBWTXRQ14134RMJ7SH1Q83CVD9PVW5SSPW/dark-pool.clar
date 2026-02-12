;; Dark Pool Trading

(define-data-var next-order-id uint u1)
(define-map hidden-orders uint { trader: principal, asset: (string-ascii 32), amount: uint, price: uint, filled: bool })

(define-public (place-hidden-order (asset (string-ascii 32)) (amount uint) (price uint))
  (let ((order-id (var-get next-order-id)))
    (map-set hidden-orders order-id { trader: tx-sender, asset: asset, amount: amount, price: price, filled: false })
    (var-set next-order-id (+ order-id u1))
    (ok order-id)
  )
)

(define-public (match-orders (order-id-1 uint) (order-id-2 uint))
  (let (
    (order1 (unwrap! (map-get? hidden-orders order-id-1) (err u100)))
    (order2 (unwrap! (map-get? hidden-orders order-id-2) (err u101)))
  )
    (asserts! (is-eq (get asset order1) (get asset order2)) (err u102))
    (asserts! (is-eq (get amount order1) (get amount order2)) (err u103))
    (map-set hidden-orders order-id-1 (merge order1 { filled: true }))
    (map-set hidden-orders order-id-2 (merge order2 { filled: true }))
    (ok true)
  )
)