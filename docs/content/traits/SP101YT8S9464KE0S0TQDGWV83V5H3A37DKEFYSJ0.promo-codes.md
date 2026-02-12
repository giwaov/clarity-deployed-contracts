---
title: "Trait promo-codes"
draft: true
---
```
;; Promo Codes - Manage promotional codes

(define-map codes
  (string-ascii 20)
  {
    discount: uint,
    uses: uint,
    max-uses: uint,
    active: bool
  }
)

(define-public (create-code (code (string-ascii 20)) (discount uint) (max-uses uint))
  (begin
    (map-set codes code {
      discount: discount,
      uses: u0,
      max-uses: max-uses,
      active: true
    })
    (ok true)
  )
)

(define-public (use-code (code (string-ascii 20)))
  (let ((promo (unwrap! (map-get? codes code) (err u404))))
    (asserts! (get active promo) (err u400))
    (asserts! (< (get uses promo) (get max-uses promo)) (err u400))
    (map-set codes code (merge promo { uses: (+ (get uses promo) u1) }))
    (ok (get discount promo))
  )
)

(define-read-only (get-code (code (string-ascii 20)))
  (map-get? codes code)
)

```
