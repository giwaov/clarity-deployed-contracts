;; Contract: Escrow Payment
;; Description: Release funds only when job is done.

(define-public (pay-freelancer (job-id uint) (worker principal) (amount uint))
    (let
        (
            (job (unwrap! (contract-call? .jobs get-job job-id) (err u404)))
        )
        ;; Verify job status from the first contract
        (asserts! (get is-done job) (err u400))
        
        ;; Transfer funds
        (stx-transfer? amount tx-sender worker)
    )
)