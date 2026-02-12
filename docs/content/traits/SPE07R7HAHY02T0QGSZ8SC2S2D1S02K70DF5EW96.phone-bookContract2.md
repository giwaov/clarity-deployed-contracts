---
title: "Trait phone-bookContract2"
draft: true
---
```
;; Phone Book Smart Contract
;; Clarity Version: 4
;; Epoch: 3.0

;; -------------------------
;; ERROR CODES
;; -------------------------
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ENTRY_NOT_FOUND (err u101))
(define-constant ERR_INVALID_PHONE (err u102))

;; -------------------------
;; STORAGE
;; -------------------------
(define-data-var last-id uint u0)

(define-map phone-book
  { id: uint }
  {
    owner: principal,
    name: (string-utf8 100),
    phone: (string-utf8 20),
    created-at: uint,
    updated-at: uint
  }
)

;; -------------------------
;; PRIVATE HELPERS
;; -------------------------
(define-private (assert-entry-owner (id uint))
  (let ((entry (map-get? phone-book { id: id })))
    (asserts! (is-some entry) ERR_ENTRY_NOT_FOUND)
    (asserts!
      (is-eq (get owner (unwrap-panic entry)) tx-sender)
      ERR_UNAUTHORIZED
    )
    (ok true)
  )
)

;; Lightweight phone validation (length only)
(define-private (is-valid-phone (phone (string-utf8 20)))
  (let ((len (len phone)))
    (and (> len u0) (<= len u20))
  )
)

;; -------------------------
;; PUBLIC FUNCTIONS
;; -------------------------

;; Add a new entry
(define-public (add-entry
  (name (string-utf8 100))
  (phone (string-utf8 20))
)
  (let (
    (new-id (+ (var-get last-id) u1))
    (now burn-block-height)
  )
    (asserts! (is-valid-phone phone) ERR_INVALID_PHONE)
    (var-set last-id new-id)
    (map-set phone-book { id: new-id } {
      owner: tx-sender,
      name: name,
      phone: phone,
      created-at: now,
      updated-at: now
    })
    (ok new-id)
  )
)

;; Update an entry
(define-public (update-entry
  (id uint)
  (name (string-utf8 100))
  (phone (string-utf8 20))
)
  (let ((entry (map-get? phone-book { id: id })))
    (asserts! (is-some entry) ERR_ENTRY_NOT_FOUND)
    (asserts! (is-valid-phone phone) ERR_INVALID_PHONE)
    (try! (assert-entry-owner id))

    (map-set phone-book { id: id } {
      owner: (get owner (unwrap-panic entry)),
      name: name,
      phone: phone,
      created-at: (get created-at (unwrap-panic entry)),
      updated-at: burn-block-height
    })
    (ok true)
  )
)

;; Delete an entry
(define-public (delete-entry (id uint))
  (let ((authorized (try! (assert-entry-owner id))))
    (if authorized
        (begin
          (map-delete phone-book { id: id })
          (ok true)
        )
        ERR_UNAUTHORIZED
    )
  )
)

;; -------------------------
;; READ-ONLY FUNCTIONS
;; -------------------------

;; Get one entry by ID
(define-read-only (get-entry (id uint))
  (match (map-get? phone-book { id: id })
    entry (some (merge entry { id: id }))
    none
  )
)

;; Total entries ever created
(define-read-only (get-entry-count)
  (var-get last-id)
)

```
