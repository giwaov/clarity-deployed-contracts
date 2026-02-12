---
title: "Trait nova-collaborative-whiteboard"
draft: true
---
```

;; nova-collaborative-whiteboard.clar
;; Shared canvas state
;; CLARITY VERSION: 2

(define-map pixels
    {x: uint, y: uint}
    (string-ascii 6) ;; Hex color
)

(define-public (draw-pixel (x uint) (y uint) (color (string-ascii 6)))
    (begin
        (map-set pixels {x: x, y: y} color)
        (ok true)
    )
)

(define-read-only (get-pixel (x uint) (y uint))
    (default-to "FFFFFF" (map-get? pixels {x: x, y: y}))
)

```
