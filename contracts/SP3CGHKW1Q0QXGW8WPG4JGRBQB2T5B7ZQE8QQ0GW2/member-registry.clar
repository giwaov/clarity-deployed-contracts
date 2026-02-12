;; Member Registry
(define-map members principal {username: (string-ascii 30), email: (string-ascii 100)})
(define-public (register-member (username (string-ascii 30)) (email (string-ascii 100)))
  (begin (map-set members tx-sender {username: username, email: email}) (ok true)))
(define-read-only (get-member (user principal))
  (map-get? members user))
