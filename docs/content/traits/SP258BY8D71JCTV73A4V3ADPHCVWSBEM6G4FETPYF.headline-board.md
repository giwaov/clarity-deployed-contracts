---
title: "Trait headline-board"
draft: true
---
```
;; headline-board.clar
;; Public forum for sharing hot news headlines

;; Constants
(define-constant ERR-HEADLINE-NOT-FOUND (err u100))
(define-constant ERR-NOT-AUTHOR (err u101))
(define-constant ERR-EMPTY-CONTENT (err u102))

;; Data Variables
(define-data-var headline-counter uint u0)

;; Maps
(define-map headlines uint 
  {
    author: principal,
    content: (string-ascii 256),
    category: uint,
    timestamp: uint,
    reply-count: uint,
    reaction-count: uint
  }
)

;; Public Functions
(define-public (post-headline (content (string-ascii 256)) (category uint))
  (let ((headline-id (+ (var-get headline-counter) u1)))
    (begin
      (asserts! (> (len content) u0) ERR-EMPTY-CONTENT)
      (asserts! (<= category u10) (err u103))
      (map-set headlines headline-id {
        author: tx-sender,
        content: content,
        category: category,
        timestamp: stacks-block-time,
        reply-count: u0,
        reaction-count: u0
      })
      (var-set headline-counter headline-id)
      (ok headline-id)
    )
  )
)

(define-public (edit-headline (headline-id uint) (new-content (string-ascii 256)))
  (let ((headline (unwrap! (map-get? headlines headline-id) ERR-HEADLINE-NOT-FOUND)))
    (begin
      (asserts! (is-eq (get author headline) tx-sender) ERR-NOT-AUTHOR)
      (asserts! (> (len new-content) u0) ERR-EMPTY-CONTENT)
      (map-set headlines headline-id (merge headline { content: new-content }))
      (ok true)
    )
  )
)

;; Read-only
(define-read-only (get-headline (headline-id uint))
  (map-get? headlines headline-id)
)

(define-read-only (get-headline-count)
  (ok (var-get headline-counter))
)

```
