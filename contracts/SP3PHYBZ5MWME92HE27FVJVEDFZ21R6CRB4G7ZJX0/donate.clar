;; Contract: Donation Handler
;; Description: Processes donations safely.

(define-public (donate-to (charity principal) (amount uint))
    (let
        (
            ;; Verify the charity is in the whitelist contract
            (valid (contract-call? .causes is-verified charity))
        )
        (asserts! valid (err u400)) ;; Error if not verified
        
        ;; Transfer funds directly to the charity
        (stx-transfer? amount tx-sender charity)
    )
)