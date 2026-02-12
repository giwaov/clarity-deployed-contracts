(define-map reputation-scores
  principal
  uint
)

(define-public (update-reputation
    (user principal)
    (score uint)
  )
  (begin
    (asserts! (not (is-eq user tx-sender)) (err u1))
    (asserts! (<= score u100) (err u2))
    (map-set reputation-scores user score)
    (ok true)
  )
)

(define-read-only (get-reputation (user principal))
  (ok (default-to u0 (map-get? reputation-scores user)))
)
