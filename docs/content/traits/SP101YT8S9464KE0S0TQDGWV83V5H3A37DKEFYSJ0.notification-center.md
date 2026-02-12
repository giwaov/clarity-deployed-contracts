---
title: "Trait notification-center"
draft: true
---
```
;; Notification Center - Simple notification system

(define-map notifications
  uint
  {
    sender: principal,
    recipient: principal,
    message: (string-utf8 500),
    created-at: uint
  }
)

(define-data-var notification-id uint u0)

(define-public (send-notification (recipient principal) (message (string-utf8 500)))
  (let ((id (var-get notification-id)))
    (map-set notifications id {
      sender: tx-sender,
      recipient: recipient,
      message: message,
      created-at: stacks-block-height
    })
    (var-set notification-id (+ id u1))
    (ok id)
  )
)

(define-read-only (get-notification (id uint))
  (map-get? notifications id)
)

```
