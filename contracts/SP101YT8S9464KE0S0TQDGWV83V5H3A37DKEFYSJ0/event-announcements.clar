;; Event Announcements - Post announcements

(define-map announcements
  uint
  {
    creator: principal,
    title: (string-utf8 100),
    message: (string-utf8 500),
    created-at: uint
  }
)

(define-data-var announcement-counter uint u0)

(define-public (post-announcement (title (string-utf8 100)) (message (string-utf8 500)))
  (let ((id (var-get announcement-counter)))
    (map-set announcements id {
      creator: tx-sender,
      title: title,
      message: message,
      created-at: stacks-block-height
    })
    (var-set announcement-counter (+ id u1))
    (ok id)
  )
)

(define-read-only (get-announcement (id uint))
  (map-get? announcements id)
)
