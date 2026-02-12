---
title: "Trait time-lock-alpha"
draft: true
---
```
;; Time-lock contract for delayed execution
(define-map locked-operations {id: uint} {data: (buff 256), unlock-time: uint, claimed: bool})
(define-data-var operation-counter uint u0)

(define-read-only (get-operation (id uint))
  (map-get? locked-operations {id: id})
)

(define-public (lock-operation (data (buff 256)) (delay uint))
  (let ((id (var-get operation-counter)) (unlock-time (+ burn-block-height delay)))
    (begin
      (map-set locked-operations {id: id} {data: data, unlock-time: unlock-time, claimed: false})
      (ok (var-set operation-counter (+ id u1)))
    )
  )
)

(define-public (execute-operation (id uint))
  (let ((op (unwrap! (map-get? locked-operations {id: id}) (err u1))))
    (begin
      (asserts! (>= burn-block-height (get unlock-time op)) (err u2))
      (asserts! (not (get claimed op)) (err u3))
      (map-set locked-operations {id: id} (merge op {claimed: true}))
      (ok true)
    )
  )
)

```
