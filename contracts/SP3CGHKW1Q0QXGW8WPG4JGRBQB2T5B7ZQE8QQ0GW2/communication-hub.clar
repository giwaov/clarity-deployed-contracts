;; Message Board - Post messages
(define-map messages uint {author: principal, content: (string-ascii 280)})
(define-data-var message-id uint u0)

(define-public (post-message (content (string-ascii 280)))
  (let ((id (var-get message-id)))
    (map-set messages id {author: tx-sender, content: content})
    (var-set message-id (+ id u1))
    (ok id)))

(define-read-only (get-message (id uint))
  (map-get? messages id))
