;; Product Registry

(define-data-var next-product-id uint u1)

(define-map products uint { manufacturer: principal, name: (string-ascii 64), verified: bool })

(define-public (register-product (name (string-ascii 64)))
  (let ((product-id (var-get next-product-id)))
    (map-set products product-id { manufacturer: tx-sender, name: name, verified: false })
    (var-set next-product-id (+ product-id u1))
    (ok product-id)
  )
)
