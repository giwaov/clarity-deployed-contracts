;; Authorization
(define-map authorized {user: principal, action: (string-ascii 50)} {allowed: bool})
(define-public (authorize (action (string-ascii 50)))
  (begin (map-set authorized {user: tx-sender, action: action} {allowed: true}) (ok true)))
(define-read-only (is-authorized (user principal) (action (string-ascii 50)))
  (default-to false (get allowed (map-get? authorized {user: user, action: action}))))
