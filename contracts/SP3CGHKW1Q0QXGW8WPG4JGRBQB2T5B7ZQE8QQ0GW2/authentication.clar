;; Authentication
(define-map auth-records principal {method: (string-ascii 30), verified: bool})
(define-public (authenticate (method (string-ascii 30)))
  (begin (map-set auth-records tx-sender {method: method, verified: true}) (ok true)))
(define-read-only (is-authenticated (user principal))
  (default-to false (get verified (map-get? auth-records user))))
