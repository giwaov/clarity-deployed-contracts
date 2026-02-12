---
title: "Trait media-uploads"
draft: true
---
```
;; Media Uploads

(define-map media
  uint
  { owner: principal, url: (string-ascii 200), mediaType: (string-ascii 20) }
)

(define-data-var counter uint u0)

(define-public (upload-media (url (string-ascii 200)) (mediaType (string-ascii 20)))
  (let ((id (var-get counter)))
    (map-set media id { owner: tx-sender, url: url, mediaType: mediaType })
    (var-set counter (+ id u1))
    (ok id)
  )
)

(define-public (delete-media (id uint))
  (let ((m (unwrap! (map-get? media id) (err u404))))
    (asserts! (is-eq (get owner m) tx-sender) (err u403))
    (map-delete media id)
    (ok true)
  )
)

(define-read-only (get-media (id uint))
  (map-get? media id)
)

```
