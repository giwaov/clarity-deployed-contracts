---
title: "Trait posts"
draft: true
---
```
;; Posts
(define-map posts uint {author: principal, content: (string-ascii 500), likes: uint})
(define-data-var post-id uint u0)
(define-public (create-post (content (string-ascii 500)))
  (let ((id (var-get post-id)))
    (map-set posts id {author: tx-sender, content: content, likes: u0})
    (var-set post-id (+ id u1))
    (ok id)))
(define-read-only (get-post (id uint))
  (map-get? posts id))

```
