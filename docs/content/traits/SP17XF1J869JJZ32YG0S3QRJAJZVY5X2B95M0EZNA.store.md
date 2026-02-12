---
title: "Trait store"
draft: true
---
```
;; simple-kv-store.clar

(define-map kv {key: (string-ascii 32)} {val: (string-ascii 140)})

(define-public (put (key (string-ascii 32)) (val (string-ascii 140)))
  (begin
    (map-set kv {key: key} {val: val})
    (ok true)))

(define-read-only (get-value (key (string-ascii 32)))
  (map-get? kv {key: key}))
```
