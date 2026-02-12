(define-map scores principal uint)

(define-public (submit-score (score uint))
  (begin
    (map-set scores tx-sender score)
    (ok score)
  )
)
