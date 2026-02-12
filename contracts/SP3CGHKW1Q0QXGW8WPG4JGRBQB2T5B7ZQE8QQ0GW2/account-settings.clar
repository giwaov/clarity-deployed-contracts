;; Account Settings
(define-map settings principal {email: (string-ascii 100), notifications: bool})
(define-public (update-settings (email (string-ascii 100)) (notifications bool))
  (begin (map-set settings tx-sender {email: email, notifications: notifications}) (ok true)))
(define-read-only (get-settings (user principal))
  (map-get? settings user))
