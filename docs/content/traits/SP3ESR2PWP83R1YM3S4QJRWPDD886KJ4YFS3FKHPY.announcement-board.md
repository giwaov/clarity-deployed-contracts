---
title: "Trait announcement-board"
draft: true
---
```
;; Announcement Board

(define-map announcements
  uint
  { creator: principal, message: (string-ascii 250), pinned: bool }
)

(define-data-var counter uint u0)

(define-public (post-announcement (message (string-ascii 250)))
  (let ((id (var-get counter)))
    (map-set announcements id { creator: tx-sender, message: message, pinned: false })
    (var-set counter (+ id u1))
    (ok id)
  )
)

(define-public (pin-announcement (id uint))
  (let ((ann (unwrap! (map-get? announcements id) (err u404))))
    (asserts! (is-eq (get creator ann) tx-sender) (err u403))
    (map-set announcements id (merge ann { pinned: true }))
    (ok true)
  )
)

(define-public (unpin-announcement (id uint))
  (let ((ann (unwrap! (map-get? announcements id) (err u404))))
    (asserts! (is-eq (get creator ann) tx-sender) (err u403))
    (map-set announcements id (merge ann { pinned: false }))
    (ok true)
  )
)

(define-read-only (get-announcement (id uint))
  (map-get? announcements id)
)

```
