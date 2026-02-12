(use-trait ft-trait .orange-sip010-ft-trait-v19.ft-trait)

(define-data-var contract-owner principal tx-sender)
(define-data-var token-price uint u1000000)

(define-read-only (get-owner) (ok (var-get contract-owner)))
(define-read-only (get-price) (ok (var-get token-price)))

(define-public (set-owner (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) (err u100))
        (var-set contract-owner new-owner)
        (ok true)
    )
)

(define-public (set-price (new-price uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) (err u100))
        (var-set token-price new-price)
        (ok true)
    )
)

(define-public (buy-token (amount uint) (token-trait <ft-trait>))
    (let
        (
            (cost (* amount (var-get token-price)))
            (buyer tx-sender)
            (owner (var-get contract-owner))
        )
        (begin
            (try! (stx-transfer? cost buyer owner))
            ;; Use direct transfer: the Token v19 contract authorizes contract-caller
            (try! (contract-call? token-trait transfer amount current-contract buyer none))
            (ok true)
        )
    )
)
