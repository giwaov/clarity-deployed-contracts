---
title: "Trait notepadContract41"
draft: true
---
```
;; Notepad Smart Contract
;; Clarity Version: 4
;; Epoch: 3.0

;; -------------------------
;; ERROR CODES
;; -------------------------
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_NOTE_NOT_FOUND (err u101))

;; -------------------------
;; STORAGE
;; -------------------------
(define-data-var last-id uint u0)

(define-map notes
  { id: uint }
  {
    owner: principal,
    title: (string-utf8 100),
    content: (string-utf8 1000),
    created-at: uint,
    updated-at: uint
  }
)

;; -------------------------
;; PRIVATE HELPERS
;; -------------------------
(define-private (assert-note-owner (id uint))
  (let ((note (map-get? notes { id: id })))
    (asserts! (is-some note) ERR_NOTE_NOT_FOUND)
    (asserts!
      (is-eq (get owner (unwrap-panic note)) tx-sender)
      ERR_NOT_AUTHORIZED
    )
    (ok true)
  )
)


;; -------------------------
;; PUBLIC FUNCTIONS
;; -------------------------

;; Create a note
(define-public (create-note
  (title (string-utf8 100))
  (content (string-utf8 1000))
)
  (let (
    (new-id (+ (var-get last-id) u1))
    (now burn-block-height)
  )
    (var-set last-id new-id)
    (map-set notes { id: new-id } {
      owner: tx-sender,
      title: title,
      content: content,
      created-at: now,
      updated-at: now
    })
    (ok new-id)
  )
)

;; Update a note
(define-public (update-note
  (id uint)
  (title (string-utf8 100))
  (content (string-utf8 1000))
)
  (let ((note (map-get? notes { id: id })))
    (asserts! (is-some note) ERR_NOTE_NOT_FOUND)
    (try! (assert-note-owner id))

    (map-set notes { id: id } {
      owner: (get owner (unwrap-panic note)),
      title: title,
      content: content,
      created-at: (get created-at (unwrap-panic note)),
      updated-at: burn-block-height
    })
    (ok true)
  )
)

;; Delete a note
(define-public (delete-note (id uint))
  (let ((authorized (try! (assert-note-owner id))))
    (if authorized
        (begin
          (map-delete notes { id: id })
          (ok true)
        )
        ERR_NOT_AUTHORIZED
    )
  )
)

;; -------------------------
;; READ-ONLY FUNCTIONS
;; -------------------------

;; Get a note by ID
(define-read-only (get-note (id uint))
  (match (map-get? notes { id: id })
    note
      (some (merge note { id: id }))
    none
  )
)

;; Total number of notes created
(define-read-only (get-note-count)
  (var-get last-id)
)

```
