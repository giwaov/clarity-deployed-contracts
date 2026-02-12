---
title: "Trait nova-date-utils"
draft: true
---
```

;; nova-date-utils.clar
;; Date helpers
;; CLARITY VERSION: 2

(define-constant BLOCKS-PER-DAY u144)

(define-read-only (blocks-to-days (blocks uint))
    (/ blocks BLOCKS-PER-DAY)
)

```
