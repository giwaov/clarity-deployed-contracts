;; Storage Contract V1
(define-map data-store principal (string-ascii 256))

(define-public (store-data (value (string-ascii 256)))
  (ok (map-set data-store tx-sender value)))

(define-read-only (get-data (user principal))
  (map-get? data-store user))

(define-public (delete-data)
  (ok (map-delete data-store tx-sender)))