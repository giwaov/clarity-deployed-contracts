;; Vault Contract

(define-constant err-insufficient-balance (err u100))

(define-map deposits principal uint)
(define-data-var total-deposits uint u0)
(define-data-var share-price uint u1000000)

(define-read-only (get-share-price)
  (var-get share-price)
)

(define-public (deposit (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set deposits tx-sender (+ (default-to u0 (map-get? deposits tx-sender)) amount))
    (var-set total-deposits (+ (var-get total-deposits) amount))
    (ok amount)
  )
)

(define-public (withdraw (amount uint))
  (let ((balance (default-to u0 (map-get? deposits tx-sender))))
    (asserts! (>= balance amount) err-insufficient-balance)
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (map-set deposits tx-sender (- balance amount))
    (var-set total-deposits (- (var-get total-deposits) amount))
    (ok amount)
  )
)
