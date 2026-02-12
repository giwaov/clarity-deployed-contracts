;; Coupon Codes
(define-map coupons {coupon-code: (string-ascii 20)} {creator: principal, discount: uint, max-uses: uint, used-count: uint, expires-at: uint})
(define-public (create-coupon (coupon-code (string-ascii 20)) (discount uint) (max-uses uint) (used-count uint) (expires-at uint))
  (begin (map-set coupons {coupon-code: coupon-code} {creator: tx-sender, discount: discount, max-uses: max-uses, used-count: used-count, expires-at: expires-at}) (ok true)))
(define-read-only (get-coupon (coupon-code (string-ascii 20)))
  (map-get? coupons {coupon-code: coupon-code}))
