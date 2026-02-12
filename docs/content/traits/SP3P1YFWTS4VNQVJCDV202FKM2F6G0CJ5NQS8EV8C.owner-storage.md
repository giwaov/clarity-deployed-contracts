---
title: "Trait owner-storage"
draft: true
---
```
;; owner-storage.clar
;; Only the owner can write, anyone can read

(define-data-var storage (string-utf8 256) u"")
(define-data-var owner principal tx-sender)

(define-read-only (get-value)
    (ok (var-get storage))
)

(define-public (set-value (new-val (string-utf8 256)))
    (begin
        (asserts! (is-eq tx-sender (var-get owner)) (err u100)) ;; ERR_NOT_OWNER
        (var-set storage new-val)
        (ok true)
    )
)

(define-public (set-owner (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get owner)) (err u100))
        (var-set owner new-owner)
        (ok true)
    )
)

```
