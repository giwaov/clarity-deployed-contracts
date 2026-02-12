---
title: "Trait message-board-srt"
draft: true
---
```
;; Simple message board contract
(define-map messages {id: uint} {author: principal, content: (string-utf8 512), timestamp: uint})
(define-data-var message-counter uint u0)

(define-read-only (get-message (id uint))
  (map-get? messages {id: id})
)

(define-read-only (get-total-messages)
  (var-get message-counter)
)

(define-public (post-message (content (string-utf8 512)))
  (let ((id (var-get message-counter)))
    (begin
      (asserts! (> (len content) u0) (err u1))
      (map-set messages {id: id} {
        author: tx-sender,
        content: content,
        timestamp: burn-block-height
      })
      (ok (var-set message-counter (+ id u1)))
    )
  )
)

```
