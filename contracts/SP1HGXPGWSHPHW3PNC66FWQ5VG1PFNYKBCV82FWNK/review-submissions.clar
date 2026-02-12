;; Review Submissions
(define-map reviews {item-id: uint, reviewer: principal} {score: uint, comment: (string-ascii 300)})
(define-public (submit-review (item-id uint) (score uint) (comment (string-ascii 300)))
  (begin (map-set reviews {item-id: item-id, reviewer: tx-sender} {score: score, comment: comment}) (ok true)))
(define-read-only (get-review (item-id uint) (reviewer principal))
  (map-get? reviews {item-id: item-id, reviewer: reviewer}))
