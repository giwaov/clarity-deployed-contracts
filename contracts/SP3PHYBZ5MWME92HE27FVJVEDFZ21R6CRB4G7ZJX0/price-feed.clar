;; Contract: Price Feed Oracle
;; Description: Stores trusted data.

(define-data-var btc-price uint u0)
(define-constant oracle-owner tx-sender)

(define-public (update-price (new-price uint))
    (begin
        (asserts! (is-eq tx-sender oracle-owner) (err u403))
        (var-set btc-price new-price)
        (ok "Price Updated")
    )
)

(define-read-only (get-price)
    (ok (var-get btc-price))
)