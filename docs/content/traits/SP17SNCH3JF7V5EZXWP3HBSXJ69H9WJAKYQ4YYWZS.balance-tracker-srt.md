---
title: "Trait balance-tracker-srt"
draft: true
---
```
;; Balance tracking contract
(define-map balances principal uint)
(define-data-var total-supply uint u0)

(define-read-only (get-balance (user principal))
  (default-to u0 (map-get? balances user))
)

(define-read-only (get-total-supply)
  (var-get total-supply)
)

(define-public (add-balance (user principal) (amount uint))
  (let ((current (get-balance user)))
    (begin
      (asserts! (> amount u0) (err u1))
      (map-set balances user (+ current amount))
      (ok (var-set total-supply (+ (var-get total-supply) amount)))
    )
  )
)

(define-public (reduce-balance (user principal) (amount uint))
  (let ((current (get-balance user)))
    (begin
      (asserts! (>= current amount) (err u2))
      (map-set balances user (- current amount))
      (ok (var-set total-supply (- (var-get total-supply) amount)))
    )
  )
)

```
