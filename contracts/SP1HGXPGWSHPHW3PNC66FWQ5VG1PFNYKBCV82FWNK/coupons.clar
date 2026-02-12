;; Coupons
(define-map coupons (string-ascii 20) {value: uint, uses: uint, max-uses: uint})
(define-public (create-coupon (code (string-ascii 20)) (value uint) (max-uses uint))
  (begin (map-set coupons code {value: value, uses: u0, max-uses: max-uses}) (ok true)))
(define-read-only (get-coupon (code (string-ascii 20)))
  (map-get? coupons code))
