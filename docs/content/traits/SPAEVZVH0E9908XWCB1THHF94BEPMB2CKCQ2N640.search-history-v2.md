---
title: "Trait search-history-v2"
draft: true
---
```
;; Search History Contract
;; Users can save addresses they search for

;; Store list of searched addresses per user
;; Key: user principal, Value: list of addresses (max 20)
;; Store individual search entries indexed by user and a counter
(define-map search-log
  {
    user: principal,
    id: uint,
  }
  principal
)

;; Keep track of how many items a user has saved
(define-map user-count
  principal
  uint
)

;; Error codes
(define-constant ERR-ALREADY-EXISTS (err u2))

;; Add an address to user's search history
(define-public (add-to-history (searched-address principal))
  (let (
      (current-count (default-to u0 (map-get? user-count tx-sender)))
      (next-count (+ current-count u1))
    )
    ;; We allow duplicates now as it is a log, or we could check?
    ;; The user prompt implies "save... generated addresses".
    ;; Removing duplicate check because checking previous entries in a map is expensive (requires loop or another map).
    ;; To keep it simple and allow "saving", we just append.

    (map-set search-log {
      user: tx-sender,
      id: next-count,
    }
      searched-address
    )
    (map-set user-count tx-sender next-count)
    (ok next-count)
  )
)

;; Get total number of searches for a user
(define-read-only (get-user-count (user principal))
  (default-to u0 (map-get? user-count user))
)

;; Get a specific search entry
(define-read-only (get-entry
    (user principal)
    (id uint)
  )
  (map-get? search-log {
    user: user,
    id: id,
  })
)

;; Clear user's search history (resets count)
(define-public (clear-history)
  (ok (map-set user-count tx-sender u0))
)

```
