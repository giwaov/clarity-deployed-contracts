;; ============================================
;; PENALTY POOL - Fund Redistribution
;; Clarity 2 Smart Contract
;; ============================================

(define-constant ERR_UNAUTHORIZED (err u401))

(define-data-var vault-contract principal tx-sender)
(define-constant CONTRACT_OWNER tx-sender)

(define-public (set-vault-contract (new-vault principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq new-vault tx-sender)) ERR_UNAUTHORIZED)
    (ok (var-set vault-contract new-vault))
  )
)

(define-public (receive-penalty (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender .penalty-pool))
    (ok true)
  )
)

(define-public (request-reward (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq contract-caller (var-get vault-contract)) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq recipient (as-contract tx-sender))) ERR_UNAUTHORIZED)
    (if (> amount u0)
      (as-contract (stx-transfer? amount tx-sender recipient))
      (ok true)
    )
  )
)

(define-read-only (get-balance)
  (ok (stx-get-balance .penalty-pool))
)
