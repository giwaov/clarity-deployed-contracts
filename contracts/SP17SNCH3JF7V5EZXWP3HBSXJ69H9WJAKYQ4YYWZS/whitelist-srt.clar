;; Whitelist management contract
(define-map whitelisted principal bool)
(define-data-var admin principal tx-sender)
(define-data-var whitelist-count uint u0)

(define-read-only (is-whitelisted (address principal))
  (default-to false (map-get? whitelisted address))
)

(define-read-only (get-count)
  (var-get whitelist-count)
)

(define-public (add-to-whitelist (address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (asserts! (not (is-whitelisted address)) (err u2))
    (map-set whitelisted address true)
    (ok (var-set whitelist-count (+ (var-get whitelist-count) u1)))
  )
)

(define-public (remove-from-whitelist (address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (asserts! (is-whitelisted address) (err u3))
    (map-delete whitelisted address)
    (ok (var-set whitelist-count (- (var-get whitelist-count) u1)))
  )
)
