;; Feedback Ratings
(define-map ratings {item-id: uint, rater: principal} {score: uint, comment: (string-ascii 200), rated-at: uint})
(define-public (submit-rating (item-id uint) (score uint) (comment (string-ascii 200)) (rated-at uint))
  (begin (map-set ratings {item-id: item-id, rater: tx-sender} {score: score, comment: comment, rated-at: rated-at}) (ok true)))
(define-read-only (get-rating (item-id uint) (rater principal))
  (map-get? ratings {item-id: item-id, rater: rater}))
