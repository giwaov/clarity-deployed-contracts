;; ============================================
;; PENALTY POOL - Fund Redistribution
;; Clarity 2 Smart Contract
;; ============================================

(define-constant ERR_UNAUTHORIZED (err u401))

(define-public (receive-penalty (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender .penalty-pool))
    (ok true)
  )
)

(define-public (request-reward (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq contract-caller .procrastination-vault) ERR_UNAUTHORIZED)
    (if (> amount u0)
      (as-contract (stx-transfer? amount tx-sender recipient))
      (ok true)
    )
  )
)

(define-read-only (get-balance)
  (ok (stx-get-balance .penalty-pool))
)
