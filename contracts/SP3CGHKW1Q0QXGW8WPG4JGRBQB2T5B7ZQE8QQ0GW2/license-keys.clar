;; License Keys
(define-map licenses (string-ascii 64) {owner: principal, product: (string-ascii 50), valid-until: uint})
(define-public (register-license (key (string-ascii 64)) (product (string-ascii 50)) (valid-until uint))
  (begin (map-set licenses key {owner: tx-sender, product: product, valid-until: valid-until}) (ok true)))
(define-read-only (get-license (key (string-ascii 64)))
  (map-get? licenses key))
