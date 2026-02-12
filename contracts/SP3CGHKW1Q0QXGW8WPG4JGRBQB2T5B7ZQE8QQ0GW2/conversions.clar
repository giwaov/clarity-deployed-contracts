;; Conversions
(define-map conversions {campaign: (string-ascii 50), user: principal} {converted: bool})
(define-public (track-conversion (campaign (string-ascii 50)))
  (begin (map-set conversions {campaign: campaign, user: tx-sender} {converted: true}) (ok true)))
(define-read-only (has-converted (campaign (string-ascii 50)) (user principal))
  (default-to false (get converted (map-get? conversions {campaign: campaign, user: user}))))
