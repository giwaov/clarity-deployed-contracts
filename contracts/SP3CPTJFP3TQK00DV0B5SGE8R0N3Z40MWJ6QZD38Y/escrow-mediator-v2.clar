;; escrow-mediator.clar
;; 2 of 3 multisig for escrow (Buyer, Seller, Mediator)

(define-data-var locked-amount uint u0)
(define-constant BUYER tx-sender)
(define-constant SELLER 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5)
(define-constant MEDIATOR 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG)

(define-public (deposit (amount uint))
    (begin
        (asserts! (> amount u0) (err u101))
        (asserts! (is-eq tx-sender BUYER) (err u102))
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (var-set locked-amount amount)
        (ok true)
    )
)

(define-read-only (get-locked-amount)
    (ok (var-get locked-amount))
)

(define-public (release)
    (begin
        ;; Logic: Requires 2 sigs (simplified for stub)
        (asserts! (or (is-eq tx-sender SELLER) (is-eq tx-sender MEDIATOR)) (err u103))
        (ok true)
    )
)
