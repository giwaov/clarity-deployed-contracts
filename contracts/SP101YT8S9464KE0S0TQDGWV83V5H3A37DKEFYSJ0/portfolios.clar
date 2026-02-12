;; Portfolios
(define-map portfolios principal {title: (string-ascii 100), projects-count: uint})
(define-public (create-portfolio (title (string-ascii 100)))
  (begin (map-set portfolios tx-sender {title: title, projects-count: u0}) (ok true)))
(define-read-only (get-portfolio (user principal))
  (map-get? portfolios user))
