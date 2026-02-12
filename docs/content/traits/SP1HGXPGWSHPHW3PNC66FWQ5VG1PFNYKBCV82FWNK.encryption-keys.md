---
title: "Trait encryption-keys"
draft: true
---
```
;; Encryption Keys
(define-map keys principal {public-key: (string-ascii 100), key-type: (string-ascii 20)})
(define-public (register-key (public-key (string-ascii 100)) (key-type (string-ascii 20)))
  (begin (map-set keys tx-sender {public-key: public-key, key-type: key-type}) (ok true)))
(define-read-only (get-key (user principal))
  (map-get? keys user))

```
