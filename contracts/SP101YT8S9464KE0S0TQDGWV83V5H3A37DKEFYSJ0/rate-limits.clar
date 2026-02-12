;; Rate Limits
(define-map rate-limits principal {requests: uint, limit: uint})
(define-public (set-rate-limit (limit uint))
  (begin (map-set rate-limits tx-sender {requests: u0, limit: limit}) (ok true)))
(define-read-only (get-rate-limit (user principal))
  (map-get? rate-limits user))
