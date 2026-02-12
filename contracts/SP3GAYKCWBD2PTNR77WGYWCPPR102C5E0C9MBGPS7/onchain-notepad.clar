;; onchain-notepad.clar
(define-map Notes principal (string-ascii 256))

(define-public (update-note (content (string-ascii 256)))
    (ok (map-set Notes tx-sender content))
)

(define-read-only (get-note (user principal))
    (ok (map-get? Notes user))
)

(define-public (delete-note)
    (ok (map-delete Notes tx-sender))
)