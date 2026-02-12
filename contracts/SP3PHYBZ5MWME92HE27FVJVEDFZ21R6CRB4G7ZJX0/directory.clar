;; Contract: User Directory
;; Description: Maps wallet addresses to usernames.

(define-map profiles principal (string-ascii 20))

(define-public (register-user (name (string-ascii 20)))
    (ok (map-set profiles tx-sender name))
)

(define-read-only (get-username (user principal))
    (ok (map-get? profiles user))
)