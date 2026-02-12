---
title: "Trait greeter"
draft: true
---
```
;; Greeter contract

(define-data-var greeting (string-utf8 100) u"Hello, World!")

(define-read-only (get-greeting)
    (ok (var-get greeting)))

(define-public (set-greeting (new-greeting (string-utf8 100)))
    (begin
        (var-set greeting new-greeting)
        (ok new-greeting)))

```
