(define-map contents principal (buff 32))

(define-public (save-hash (hash (buff 32)))
  (begin
    (map-set contents tx-sender hash)
    (ok hash)
  )
)
