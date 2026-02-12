;; Futures Manager

(define-data-var next-future-id uint u1)

(define-map futures uint { trader: principal, asset: (string-ascii 32), price: uint, expiry: uint })

(define-public (create-future (asset (string-ascii 32)) (price uint) (expiry uint))
  (let ((future-id (var-get next-future-id)))
    (map-set futures future-id { trader: tx-sender, asset: asset, price: price, expiry: expiry })
    (var-set next-future-id (+ future-id u1))
    (ok future-id)
  )
)
