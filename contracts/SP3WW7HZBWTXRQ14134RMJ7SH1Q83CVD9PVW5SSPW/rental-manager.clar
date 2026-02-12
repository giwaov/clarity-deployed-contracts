;; Rental Manager

(define-data-var next-rental-id uint u1)

(define-map rentals uint { property-id: uint, tenant: principal, monthly-rent: uint })

(define-public (create-rental (property-id uint) (monthly-rent uint))
  (let ((rental-id (var-get next-rental-id)))
    (map-set rentals rental-id { property-id: property-id, tenant: tx-sender, monthly-rent: monthly-rent })
    (var-set next-rental-id (+ rental-id u1))
    (ok rental-id)
  )
)
