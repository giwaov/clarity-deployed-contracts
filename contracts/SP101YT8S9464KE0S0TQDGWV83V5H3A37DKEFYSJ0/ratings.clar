;; Ratings
(define-map ratings {service-id: uint, user: principal} {stars: uint})
(define-public (rate-service (service-id uint) (stars uint))
  (begin (map-set ratings {service-id: service-id, user: tx-sender} {stars: stars}) (ok true)))
(define-read-only (get-rating (service-id uint) (user principal))
  (map-get? ratings {service-id: service-id, user: user}))
