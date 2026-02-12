(define-map subscribers principal uint)

(define-public (subscribe (until uint))
  (begin
    (map-set subscribers tx-sender until)
    (ok until)
  )
)
