---
title: "Trait ascii-lab"
draft: true
---
```
;; ascii-lab.clar
;; Experiments with Clarity 4 to-ascii? function

(define-public (convert-uint (val uint))
    (ok "mock-ascii")
)

(define-public (convert-int (val int))
    (ok "mock-ascii")
)

(define-public (convert-bool (val bool))
    (ok "mock-ascii")
)

(define-read-only (check-ascii (val uint))
    (some "mock-ascii")
)

```
