;; License Manager - Manage licenses
(define-map licenses {user: principal, license-type: (string-ascii 30)} {valid: bool})

(define-public (grant-license (license-type (string-ascii 30)))
  (begin
    (map-set licenses {user: tx-sender, license-type: license-type} {valid: true})
    (ok true)))

(define-read-only (check-license (user principal) (license-type (string-ascii 30)))
  (default-to false (get valid (map-get? licenses {user: user, license-type: license-type}))))
