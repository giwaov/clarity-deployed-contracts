;; contracts/streak-token.clar

(define-fungible-token streak-token)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_OWNER_ONLY (err u100))
(define-constant ERR_NOT_AUTHORIZED (err u101))

(define-constant STREAK_REGISTRY .streak-reg-v2)



(define-read-only (get-name)
  (ok "StacksStreak Token")
)

(define-read-only (get-symbol)
  (ok "STREAK")
)

(define-read-only (get-decimals)
  (ok u0) 
)

(define-read-only (get-balance (user principal))
  (ok (ft-get-balance streak-token user))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply streak-token))
)

(define-read-only (get-token-uri)
  (ok none)
)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err u102))
    (try! (ft-transfer? streak-token amount sender recipient))
    (match memo to-print (print to-print) 0x)
    (ok true)
  )
)



(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! 
      (or 
        (is-eq tx-sender CONTRACT_OWNER)
        (is-eq contract-caller STREAK_REGISTRY) 
      )
      ERR_NOT_AUTHORIZED
    )
    (ft-mint? streak-token amount recipient)
  )
)