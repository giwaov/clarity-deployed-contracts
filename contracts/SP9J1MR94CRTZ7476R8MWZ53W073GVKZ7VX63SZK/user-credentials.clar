;; User Credentials
(define-map credentials {user: principal} {credential-hash: (buff 32), issuer: principal, issued-at: uint, valid-until: uint})
(define-public (set-credential (credential-hash (buff 32)) (issuer principal) (issued-at uint) (valid-until uint))
  (begin (map-set credentials {user: tx-sender} {credential-hash: credential-hash, issuer: issuer, issued-at: issued-at, valid-until: valid-until}) (ok true)))
(define-read-only (get-credential (user principal))
  (map-get? credentials {user: user}))
