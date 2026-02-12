;; Simple marketplace contract
(define-map listings {id: uint} {seller: principal, price: uint, sold: bool})
(define-data-var listing-counter uint u0)
(define-map purchases {id: uint} {buyer: principal, purchase-time: uint})

(define-read-only (get-listing (id uint))
  (map-get? listings {id: id})
)

(define-public (create-listing (price uint))
  (let ((id (var-get listing-counter)))
    (begin
      (asserts! (> price u0) (err u1))
      (map-set listings {id: id} {
        seller: tx-sender,
        price: price,
        sold: false
      })
      (ok (var-set listing-counter (+ id u1)))
    )
  )
)

(define-public (buy-item (id uint))
  (let ((listing (unwrap! (map-get? listings {id: id}) (err u1))))
    (begin
      (asserts! (not (get sold listing)) (err u2))
      (map-set listings {id: id} (merge listing {sold: true}))
      (ok (map-set purchases {id: id} {buyer: tx-sender, purchase-time: burn-block-height}))
    )
  )
)
