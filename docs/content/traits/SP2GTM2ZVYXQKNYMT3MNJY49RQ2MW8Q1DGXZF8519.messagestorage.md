---
title: "Trait messagestorage"
draft: true
---
```
;; Define a variable to store a 20-character message
(define-data-var stored-message (string-ascii 20) "Hello Stacks")

;; Read-only function to fetch the message
(define-read-only (get-message)
  (ok (var-get stored-message))
)

;; Public function to update the message
(define-public (set-message (new-message (string-ascii 20)))
  (begin
    ;; Update the variable with the new input
    (var-set stored-message new-message)
    (ok true)
  )
)

```
