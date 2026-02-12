;; Permissions
(define-map permissions {user: principal, resource: (string-ascii 50)} {granted: bool})
(define-public (grant-permission (resource (string-ascii 50)))
  (begin (map-set permissions {user: tx-sender, resource: resource} {granted: true}) (ok true)))
(define-read-only (has-permission (user principal) (resource (string-ascii 50)))
  (default-to false (get granted (map-get? permissions {user: user, resource: resource}))))
