---
title: "Trait logger"
draft: true
---
```
;; Status Logger Contract
(define-data-var current-status (string-utf8 50) u"Hello Stacks")


(define-read-only (get-status)
    (ok (var-get current-status))
)


(define-public (update-status (new-message (string-utf8 50)))
    (begin
        (var-set current-status new-message)
        (ok "Status Updated Successfully")
    )
)
```
