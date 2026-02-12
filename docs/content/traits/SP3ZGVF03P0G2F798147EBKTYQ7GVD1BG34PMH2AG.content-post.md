---
title: "Trait content-post"
draft: true
---
```
;; Content Posts
(define-map posts uint {author: principal, content: (string-ascii 500), timestamp: uint})
(define-data-var post-id uint u0)
(define-public (publish-post (content (string-ascii 500)) (timestamp uint))
  (let ((id (var-get post-id)))
    (map-set posts id {author: tx-sender, content: content, timestamp: timestamp})
    (var-set post-id (+ id u1))
    (ok id)))
(define-read-only (get-post (id uint))
  (map-get? posts id))

```
