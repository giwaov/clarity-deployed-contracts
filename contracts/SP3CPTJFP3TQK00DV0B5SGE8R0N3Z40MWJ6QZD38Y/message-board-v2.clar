;; message-board.clar
;; On-chain posts

(define-map posts uint { author: principal, content: (string-utf8 280) })
(define-data-var next-id uint u0)

(define-public (write-post (content (string-utf8 280)))
    (let
        (
            (id (var-get next-id))
        )
        (asserts! (> (len content) u0) (err u105))
        (map-set posts id { author: tx-sender, content: content })
        (var-set next-id (+ id u1))
        (ok id)
    )
)

(define-read-only (get-post (id uint))
    (ok (map-get? posts id))
)
