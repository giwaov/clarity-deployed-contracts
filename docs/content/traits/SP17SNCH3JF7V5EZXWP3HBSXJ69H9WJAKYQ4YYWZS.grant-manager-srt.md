---
title: "Trait grant-manager-srt"
draft: true
---
```
;; Grant management contract
(define-map grants {id: uint} {recipient: principal, amount: uint, released: uint, total-releases: uint})
(define-data-var grant-counter uint u0)

(define-read-only (get-grant (id uint))
  (map-get? grants {id: id})
)

(define-public (create-grant (recipient principal) (amount uint) (releases uint))
  (let ((id (var-get grant-counter)))
    (begin
      (asserts! (> releases u0) (err u1))
      (map-set grants {id: id} {
        recipient: recipient,
        amount: amount,
        released: u0,
        total-releases: releases
      })
      (ok (var-set grant-counter (+ id u1)))
    )
  )
)

(define-public (release-grant (id uint))
  (let ((grant (unwrap! (map-get? grants {id: id}) (err u1))))
    (begin
      (asserts! (< (get released grant) (get total-releases grant)) (err u2))
      (ok (map-set grants {id: id} (merge grant {released: (+ (get released grant) u1)})))
    )
  )
)

```
