---
title: "Trait messages"
draft: true
---
```
;; Contract: Public Guestbook
;; Description: Anyone can leave a permanent message.

(define-map guestbook uint { user: principal, text: (string-ascii 100) })
(define-data-var msg-count uint u0)

(define-public (sign-guestbook (message (string-ascii 100)))
    (let
        (
            (new-id (+ (var-get msg-count) u1))
        )
        (map-set guestbook new-id { user: tx-sender, text: message })
        (var-set msg-count new-id)
        (ok "Message Signed!")
    )
)

(define-read-only (get-message (id uint))
    (ok (map-get? guestbook id))
)

(define-read-only (get-total-messages)
    (ok (var-get msg-count))
)
```
