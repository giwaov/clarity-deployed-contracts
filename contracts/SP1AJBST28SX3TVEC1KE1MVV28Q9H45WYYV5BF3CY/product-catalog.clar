;; Product Catalog
(define-map products {product-id: uint} {name: (string-ascii 100), price: uint, seller: principal, quantity: uint, active: bool})
(define-public (list-product (product-id uint) (name (string-ascii 100)) (price uint) (quantity uint) (active bool))
  (begin (map-set products {product-id: product-id} {name: name, price: price, seller: tx-sender, quantity: quantity, active: active}) (ok true)))
(define-read-only (get-product (product-id uint))
  (map-get? products {product-id: product-id}))
