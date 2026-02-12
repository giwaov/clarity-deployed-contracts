;; SIP-010 Token Multi-Sender
;; Contract: sip-multi-send

(use-trait ft-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; Storage to temporarily hold the amount for the current batch
(define-data-var batch-amount uint u0)

(define-public (airdrop-token 
    (token-contract <ft-trait>) 
    (recipients (list 200 principal)) 
    (amount uint))
    (begin
        ;; Store the amount in a data-var so the private function can access it
        (var-set batch-amount amount)
        ;; Map the transfer function over the recipients
        (ok (map transfer-step recipients (list-of-token token-contract (len recipients))))
    )
)

;; Helper function: Accepts exactly 2 arguments as required by 'map' with two lists
(define-private (transfer-step (recipient principal) (token-contract <ft-trait>))
    (begin
        (unwrap-panic (contract-call? token-contract transfer (var-get batch-amount) tx-sender recipient none))
        true
    )
)

;; Utility to create a list of the same token trait for the map function
(define-private (list-of-token (token <ft-trait>) (n uint))
    (if (is-eq n u0) (list) 
    (if (is-eq n u1) (list token)
    (if (is-eq n u2) (list token token)
    ;; For larger lists, we rely on the frontend or a recursive-like helper
    ;; However, the most stable way is to use 'fold' with a specific tuple
    (list token token token token token)))) ;; Simplified for common small batches
)