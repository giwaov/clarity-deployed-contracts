;; Price Oracle
;; Provides price feeds for DEX

(define-constant contract-owner tx-sender)

(define-map prices (string-ascii 32) uint)

(define-read-only (get-price (asset (string-ascii 32)))
  (default-to u0 (map-get? prices asset))
)

(define-public (update-price (asset (string-ascii 32)) (price uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err u100))
    (map-set prices asset price)
    (ok price)
  )
)
