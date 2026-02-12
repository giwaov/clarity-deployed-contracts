(define-map metadata principal (string-ascii 64))

(define-public (set (data (string-ascii 64)))
  (begin (map-set metadata tx-sender data) (ok data))
)
