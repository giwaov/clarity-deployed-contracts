---
title: "Trait bridge-connector"
draft: true
---
```
;; bridge-connector
;; Infrastructure & Oracles

(define-map config
  { key: (string-ascii 32) }
  { value: (string-ascii 256), updated-at: uint }
)

(define-map data-points
  { source: principal, id: uint }
  { value: uint, confidence: uint }
)

(define-public (update-config (key (string-ascii 32)) (val (string-ascii 256)))
  (ok (map-set config { key: key } { value: val, updated-at: block-height }))
)

(define-public (post-data (id uint) (val uint) (confidence uint))
  (ok (map-set data-points { source: tx-sender, id: id } 
    { value: val, confidence: confidence }
  ))
)
```
