(define-map invoices uint bool)

(define-public (pay (invoice-id uint))
  (begin
    (map-set invoices invoice-id true)
    (ok invoice-id)
  )
)
