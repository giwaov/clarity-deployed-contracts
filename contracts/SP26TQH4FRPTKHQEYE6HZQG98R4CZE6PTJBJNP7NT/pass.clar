(define-map passes principal uint)

(define-public (buy (season uint))
  (begin
    (map-set passes tx-sender season)
    (ok season)
  )
)
