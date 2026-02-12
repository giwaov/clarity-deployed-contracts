;; Achievement Badges - Award badges
(define-map badges {user: principal, badge-type: (string-ascii 30)} {earned: bool})

(define-public (award-badge (badge-type (string-ascii 30)))
  (begin
    (map-set badges {user: tx-sender, badge-type: badge-type} {earned: true})
    (ok true)))

(define-read-only (has-badge (user principal) (badge-type (string-ascii 30)))
  (default-to false (get earned (map-get? badges {user: user, badge-type: badge-type}))))
