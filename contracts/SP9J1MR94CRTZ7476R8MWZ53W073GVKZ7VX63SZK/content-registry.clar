;; Content Registry
(define-map content {content-id: uint} {creator: principal, title: (string-ascii 100), content-hash: (buff 32), created-at: uint, license: (string-ascii 30)})
(define-public (register-content (content-id uint) (title (string-ascii 100)) (content-hash (buff 32)) (created-at uint) (license (string-ascii 30)))
  (begin (map-set content {content-id: content-id} {creator: tx-sender, title: title, content-hash: content-hash, created-at: created-at, license: license}) (ok true)))
(define-read-only (get-content (content-id uint))
  (map-get? content {content-id: content-id}))
