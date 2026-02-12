---
title: "Trait queue-srt"
draft: true
---
```
;; Queue management contract
(define-map queue-items {position: uint} principal)
(define-data-var queue-head uint u0)
(define-data-var queue-tail uint u0)

(define-read-only (get-item (position uint))
  (map-get? queue-items {position: position})
)

(define-read-only (queue-size)
  (- (var-get queue-tail) (var-get queue-head))
)

(define-public (enqueue (user principal))
  (begin
    (asserts! (> (queue-size) u0) (err u1))
    (map-set queue-items {position: (var-get queue-tail)} user)
    (ok (var-set queue-tail (+ (var-get queue-tail) u1)))
  )
)

(define-public (dequeue)
  (let ((item (unwrap! (get-item (var-get queue-head)) (err u1))))
    (begin
      (map-delete queue-items {position: (var-get queue-head)})
      (ok (var-set queue-head (+ (var-get queue-head) u1)))
    )
  )
)

```
