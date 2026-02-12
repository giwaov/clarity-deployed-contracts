---
title: "Trait file-registry"
draft: true
---
```
;; File Registry

(define-data-var next-file-id uint u1)

(define-map files uint { owner: principal, hash: (buff 32), size: uint })

(define-public (register-file (hash (buff 32)) (size uint))
  (let ((file-id (var-get next-file-id)))
    (map-set files file-id { owner: tx-sender, hash: hash, size: size })
    (var-set next-file-id (+ file-id u1))
    (ok file-id)
  )
)

```
