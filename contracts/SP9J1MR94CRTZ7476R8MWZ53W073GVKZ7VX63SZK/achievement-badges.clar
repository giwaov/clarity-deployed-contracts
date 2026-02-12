;; Achievement Badges
(define-map badges {user: principal, badge-id: uint} {name: (string-ascii 50), description: (string-ascii 200), earned-at: uint})
(define-public (award-badge (badge-id uint) (name (string-ascii 50)) (description (string-ascii 200)) (earned-at uint))
  (begin (map-set badges {user: tx-sender, badge-id: badge-id} {name: name, description: description, earned-at: earned-at}) (ok true)))
(define-read-only (get-badge (user principal) (badge-id uint))
  (map-get? badges {user: user, badge-id: badge-id}))
