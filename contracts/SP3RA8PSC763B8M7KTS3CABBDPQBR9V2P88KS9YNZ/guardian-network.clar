;; ============================================
;; GUARDIAN NETWORK - Trusted Timer Extenders
;; Clarity 4 Smart Contract
;; ============================================

(define-constant ERR_NOT_AUTHORIZED (err u401))

(define-map guardians { user: principal, guardian: principal } bool)

(define-public (add-guardian (guardian principal))
  (begin
    (asserts! (not (is-eq guardian tx-sender)) (err u400))
    (map-set guardians { user: tx-sender, guardian: guardian } true)
    (ok true)
  )
)

(define-public (remove-guardian (guardian principal))
  (begin
    (asserts! (not (is-eq guardian tx-sender)) (err u400))
    (map-delete guardians { user: tx-sender, guardian: guardian })
    (ok true)
  )
)

(define-public (extend-timer (user principal))
  (begin
    (asserts! (default-to false (map-get? guardians { user: user, guardian: tx-sender })) ERR_NOT_AUTHORIZED)
    (as-contract (contract-call? .heartbeat-core guardian-pulse user))
  )
)

(define-read-only (is-guardian (user principal) (guardian principal))
  (default-to false (map-get? guardians { user: user, guardian: guardian }))
)
