---
title: "Trait notifications"
draft: true
---
```
;; Notifications
(define-map notifications uint {recipient: principal, text: (string-ascii 200), read: bool})
(define-data-var notification-id uint u0)
(define-public (create-notification (recipient principal) (text (string-ascii 200)))
  (let ((id (var-get notification-id)))
    (map-set notifications id {recipient: recipient, text: text, read: false})
    (var-set notification-id (+ id u1))
    (ok id)))
(define-read-only (get-notification (id uint))
  (map-get? notifications id))

```
