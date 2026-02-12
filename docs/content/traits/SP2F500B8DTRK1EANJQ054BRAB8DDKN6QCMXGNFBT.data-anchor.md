---
title: "Trait data-anchor"
draft: true
---
```
(define-map anchors principal (buff 32))

(define-public (anchor (hash (buff 32)))
  (begin
    (map-set anchors tx-sender hash)
    (ok hash)
  )
)

```
