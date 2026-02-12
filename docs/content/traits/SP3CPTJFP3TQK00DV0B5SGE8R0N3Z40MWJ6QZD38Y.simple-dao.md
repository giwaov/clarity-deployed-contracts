---
title: "Trait simple-dao"
draft: true
---
```
;; simple-dao.clar
;; Execute calls if proposal passes

(define-map proposals uint { target: principal, function: (string-ascii 30), votes: uint, executed: bool })
(define-constant THRESHOLD u100)

(define-public (propose (id uint) (target principal) (function-name (string-ascii 30)))
    (ok (map-set proposals id { target: target, function: function-name, votes: u0, executed: false }))
)

(define-public (vote (id uint))
    (let
        (
            (prop (unwrap! (map-get? proposals id) (err u404)))
        )
        (ok (map-set proposals id (merge prop { votes: (+ (get votes prop) u1) })))
    )
)

(define-public (execute (id uint))
    (let
        (
            (prop (unwrap! (map-get? proposals id) (err u404)))
        )
        (asserts! (>= (get votes prop) THRESHOLD) (err u100))
        (asserts! (not (get executed prop)) (err u101))
        (map-set proposals id (merge prop { executed: true }))
        ;; Dynamic execution is hard in Clarity without traits, simplified logic here:
        (ok true)
    )
)

```
