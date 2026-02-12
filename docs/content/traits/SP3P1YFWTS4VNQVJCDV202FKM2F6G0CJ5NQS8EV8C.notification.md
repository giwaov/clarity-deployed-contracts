---
title: "Trait notification"
draft: true
---
```
;; Notification system contract
(define-map notifications {id: uint} {recipient: principal, message: (string-utf8 256), read: bool, timestamp: uint})
(define-data-var notification-counter uint u0)

(define-read-only (get-notification (id uint))
  (map-get? notifications {id: id})
)

(define-public (send-notification (recipient principal) (message (string-utf8 256)))
  (let ((id (var-get notification-counter)))
    (begin
      (map-set notifications {id: id} {
        recipient: recipient,
        message: message,
        read: false,
        timestamp: burn-block-height
      })
      (ok (var-set notification-counter (+ id u1)))
    )
  )
)

(define-public (mark-read (id uint))
  (let ((notif (unwrap! (map-get? notifications {id: id}) (err u1))))
    (begin
      (asserts! (is-eq tx-sender (get recipient notif)) (err u2))
      (ok (map-set notifications {id: id} (merge notif {read: true})))
    )
  )
)

```
