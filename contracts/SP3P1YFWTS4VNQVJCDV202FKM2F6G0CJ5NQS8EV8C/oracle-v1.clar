;; oracle-v1.clar
;; Simple Price Oracle

(define-map prices (string-ascii 10) uint)
(define-constant ORACLE_OWNER tx-sender)

(define-public (set-price (symbol (string-ascii 10)) (price uint))
    (begin
        (asserts! (is-eq tx-sender ORACLE_OWNER) (err u100))
        (map-set prices symbol price)
        (ok true)
    )
)

(define-read-only (get-price (symbol (string-ascii 10)))
    (ok (default-to u0 (map-get? prices symbol)))
)
