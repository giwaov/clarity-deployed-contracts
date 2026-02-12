(define-map authorized-signers
  principal
  bool
)

(define-public (add-signer (signer principal))
  (begin
    (asserts! (not (is-eq signer tx-sender)) (err u1))
    (map-set authorized-signers signer true)
    (ok true)
  )
)

(define-read-only (is-signer (signer principal))
  (ok (default-to false (map-get? authorized-signers signer)))
)
