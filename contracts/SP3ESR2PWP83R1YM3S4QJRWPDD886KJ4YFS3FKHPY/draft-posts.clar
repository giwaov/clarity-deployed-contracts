;; Draft Posts

(define-map drafts
  uint
  { owner: principal, content: (string-ascii 500), published: bool }
)

(define-data-var counter uint u0)

(define-public (save-draft (content (string-ascii 500)))
  (let ((id (var-get counter)))
    (map-set drafts id { owner: tx-sender, content: content, published: false })
    (var-set counter (+ id u1))
    (ok id)
  )
)

(define-public (update-draft (id uint) (content (string-ascii 500)))
  (let ((draft (unwrap! (map-get? drafts id) (err u404))))
    (asserts! (is-eq (get owner draft) tx-sender) (err u403))
    (asserts! (not (get published draft)) (err u409))
    (map-set drafts id (merge draft { content: content }))
    (ok true)
  )
)

(define-public (publish-draft (id uint))
  (let ((draft (unwrap! (map-get? drafts id) (err u404))))
    (asserts! (is-eq (get owner draft) tx-sender) (err u403))
    (map-set drafts id (merge draft { published: true }))
    (ok true)
  )
)

(define-public (delete-draft (id uint))
  (let ((draft (unwrap! (map-get? drafts id) (err u404))))
    (asserts! (is-eq (get owner draft) tx-sender) (err u403))
    (map-delete drafts id)
    (ok true)
  )
)

(define-read-only (get-draft (id uint))
  (map-get? drafts id)
)
