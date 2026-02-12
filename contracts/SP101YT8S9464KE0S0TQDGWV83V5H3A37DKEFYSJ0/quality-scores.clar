;; Quality Scores
(define-map quality principal {score: uint, evaluations: uint})
(define-public (update-quality (score uint) (evaluations uint))
  (begin (map-set quality tx-sender {score: score, evaluations: evaluations}) (ok true)))
(define-read-only (get-quality (user principal))
  (map-get? quality user))
