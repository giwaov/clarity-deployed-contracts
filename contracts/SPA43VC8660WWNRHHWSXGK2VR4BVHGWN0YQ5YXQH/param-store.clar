;; param-store.clar
;; Stores user-specific configuration parameters/feature flags.
;; Standard application logic for persisting user settings.

(define-map params { user: principal, key: (string-ascii 24) } bool)

(define-public (update-param (key (string-ascii 24)) (value bool))
    (ok (map-set params { user: tx-sender, key: key } value))
)

(define-read-only (get-param (user principal) (key (string-ascii 24)))
    (default-to false (map-get? params { user: user, key: key }))
)
