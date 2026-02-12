(define-map players principal bool)

(define-public (register)
  (begin
    (map-set players tx-sender true)
    (ok true)
  )
)
