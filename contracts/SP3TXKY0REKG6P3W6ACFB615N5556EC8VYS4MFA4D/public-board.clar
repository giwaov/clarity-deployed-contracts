;; public-board.clar

(define-map messages {user: principal} {msg: (string-ascii 140)})

(define-public (post-message (msg (string-ascii 140)))
  (begin
    (map-set messages {user: tx-sender} {msg: msg})
    (ok true)))

(define-read-only (get-message (user principal))
  (map-get? messages {user: user}))
