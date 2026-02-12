;; note-keeper.clar
;; A contract to store a personal note for each user

(define-map notes principal (string-ascii 100))

(define-public (write-note (new-note (string-ascii 100)))
  (ok (map-set notes tx-sender new-note))
)

(define-read-only (get-note (who principal))
  (ok (default-to "" (map-get? notes who)))
)
