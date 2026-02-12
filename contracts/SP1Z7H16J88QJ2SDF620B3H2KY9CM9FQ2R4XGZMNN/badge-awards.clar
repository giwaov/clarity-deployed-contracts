;; Badge Awards
(define-map badges {recipient: principal, badge-id: uint} {badge-name: (string-ascii 30), awarded-at: uint})
(define-public (award-badge (recipient principal) (badge-id uint) (badge-name (string-ascii 30)) (awarded-at uint))
  (begin (map-set badges {recipient: recipient, badge-id: badge-id} {badge-name: badge-name, awarded-at: awarded-at}) (ok true)))
(define-read-only (get-badge (recipient principal) (badge-id uint))
  (map-get? badges {recipient: recipient, badge-id: badge-id}))
