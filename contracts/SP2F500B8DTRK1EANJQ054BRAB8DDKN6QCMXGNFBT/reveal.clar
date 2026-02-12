(define-map commits principal (buff 32))
(define-constant err-already-committed (err u402))

(define-public (commit (hash (buff 32)))
  (if (is-some (map-get? commits tx-sender))
      err-already-committed
      (begin
        (map-set commits tx-sender hash)
        (ok hash)
      )
  )
)

(define-read-only (get-commit (user principal))
  (map-get? commits user)
)
