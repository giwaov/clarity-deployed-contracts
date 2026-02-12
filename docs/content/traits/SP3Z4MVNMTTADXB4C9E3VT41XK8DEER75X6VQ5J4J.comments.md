---
title: "Trait comments"
draft: true
---
```
;; Comments
(define-map comments uint {author: principal, content: (string-ascii 300), target-id: uint})
(define-data-var comment-id uint u0)
(define-public (post-comment (content (string-ascii 300)) (target-id uint))
  (let ((id (var-get comment-id)))
    (map-set comments id {author: tx-sender, content: content, target-id: target-id})
    (var-set comment-id (+ id u1))
    (ok id)))
(define-read-only (get-comment (id uint))
  (map-get? comments id))

```
