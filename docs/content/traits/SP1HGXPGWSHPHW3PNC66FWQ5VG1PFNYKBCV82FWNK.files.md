---
title: "Trait files"
draft: true
---
```
;; Files
(define-map files uint {owner: principal, name: (string-ascii 100), size: uint})
(define-data-var file-id uint u0)
(define-public (upload-file (name (string-ascii 100)) (size uint))
  (let ((id (var-get file-id)))
    (map-set files id {owner: tx-sender, name: name, size: size})
    (var-set file-id (+ id u1))
    (ok id)))
(define-read-only (get-file (id uint))
  (map-get? files id))

```
