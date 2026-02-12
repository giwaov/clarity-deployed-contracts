;; Contract: Fund Recovery
;; Description: Emergency withdraw by guardian.

(define-public (emergency-withdraw (new-wallet principal) (amount uint))
    (let
        (
            (is-guardian (contract-call? .guardians is-trusted tx-sender))
        )
        ;; Strict check: Caller must be a guardian
        (asserts! is-guardian (err u403))
        
        ;; Move funds to safe wallet
        (as-contract (stx-transfer? amount tx-sender new-wallet))
    )
)