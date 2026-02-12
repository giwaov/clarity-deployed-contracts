;; Engagement
(define-map engagement principal {interactions: uint, score: uint})
(define-public (update-engagement (interactions uint) (score uint))
  (begin (map-set engagement tx-sender {interactions: interactions, score: score}) (ok true)))
(define-read-only (get-engagement (user principal))
  (map-get? engagement user))
