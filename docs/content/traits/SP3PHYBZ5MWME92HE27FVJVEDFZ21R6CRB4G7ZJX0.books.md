---
title: "Trait books"
draft: true
---
```
;; Contract: Book Catalog
;; Description: Stores book details and availability.

(define-map book-store uint { title: (string-ascii 50), is-available: bool })
(define-data-var book-count uint u0)

(define-public (add-book (title (string-ascii 50)))
    (let
        (
            (new-id (+ (var-get book-count) u1))
        )
        (map-set book-store new-id { title: title, is-available: true })
        (var-set book-count new-id)
        (ok new-id)
    )
)

(define-public (set-availability (id uint) (status bool))
    (let
        (
            (book (unwrap! (map-get? book-store id) (err u404)))
        )
        (map-set book-store id (merge book { is-available: status }))
        (ok "Availability Updated")
    )
)

(define-read-only (get-book (id uint))
    (map-get? book-store id)
)
```
