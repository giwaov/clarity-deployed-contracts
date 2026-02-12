;; Service Catalog - Catalog of services
(define-map catalog uint {name: (string-ascii 100), provider: principal, price: uint})
(define-data-var next-id uint u0)

(define-public (add-service (name (string-ascii 100)) (price uint))
  (let ((id (var-get next-id)))
    (map-set catalog id {name: name, provider: tx-sender, price: price})
    (var-set next-id (+ id u1))
    (ok id)))

(define-read-only (get-service (id uint))
  (map-get? catalog id))
