---
title: "Trait registry"
draft: true
---
```
;; Registry contract - store and manage entries
(define-map registry principal (string-ascii 256))
(define-data-var total-entries uint u0)

(define-read-only (get-entry (address principal))
  (map-get? registry address)
)

(define-read-only (get-total)
  (var-get total-entries)
)

(define-public (register (data (string-ascii 256)))
  (begin
    (asserts! (is-none (map-get? registry tx-sender)) (err u1))
    (map-set registry tx-sender data)
    (ok (var-set total-entries (+ (var-get total-entries) u1)))
  )
)

(define-public (update-entry (data (string-ascii 256)))
  (begin
    (asserts! (is-some (map-get? registry tx-sender)) (err u2))
    (ok (map-set registry tx-sender data))
  )
)

(define-public (remove-entry)
  (begin
    (asserts! (is-some (map-get? registry tx-sender)) (err u2))
    (map-delete registry tx-sender)
    (ok (var-set total-entries (- (var-get total-entries) u1)))
  )
)

```
