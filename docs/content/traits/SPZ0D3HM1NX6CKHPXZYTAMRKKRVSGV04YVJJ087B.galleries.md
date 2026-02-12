---
title: "Trait galleries"
draft: true
---
```
;; Galleries
(define-map galleries uint {owner: principal, name: (string-ascii 50), items-count: uint})
(define-data-var gallery-id uint u0)
(define-public (create-gallery (name (string-ascii 50)))
  (let ((id (var-get gallery-id)))
    (map-set galleries id {owner: tx-sender, name: name, items-count: u0})
    (var-set gallery-id (+ id u1))
    (ok id)))
(define-read-only (get-gallery (id uint))
  (map-get? galleries id))

```
