;; Verification System

(define-constant contract-owner tx-sender)

(define-map verified-products uint bool)

(define-public (verify-product (product-id uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err u100))
    (map-set verified-products product-id true)
    (ok true)
  )
)
