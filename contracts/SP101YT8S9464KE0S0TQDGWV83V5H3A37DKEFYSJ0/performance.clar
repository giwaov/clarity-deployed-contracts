;; Performance
(define-map performance {service-id: uint, metric: (string-ascii 30)} {score: uint})
(define-public (update-performance (service-id uint) (metric (string-ascii 30)) (score uint))
  (begin (map-set performance {service-id: service-id, metric: metric} {score: score}) (ok true)))
(define-read-only (get-performance (service-id uint) (metric (string-ascii 30)))
  (map-get? performance {service-id: service-id, metric: metric}))
