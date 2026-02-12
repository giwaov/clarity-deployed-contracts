---
title: "Trait dao-voting"
draft: true
---
```
;; dao-voting.clar
(define-map proposals uint { yes: uint, no: uint })
(define-data-var proposal-count uint u0)

(define-public (create-proposal)
  (let ((id (+ (var-get proposal-count) u1)))
    (begin
      (var-set proposal-count id)
      (map-set proposals id { yes: u0, no: u0 })
      (ok id))))

(define-public (vote (id uint) (support bool))
  (let ((p (unwrap! (map-get? proposals id) (err u404))))
    (if support
      (map-set proposals id { yes: (+ (get yes p) u1), no: (get no p) })
      (map-set proposals id { yes: (get yes p), no: (+ (get no p) u1) }))
    (ok true)))

```
