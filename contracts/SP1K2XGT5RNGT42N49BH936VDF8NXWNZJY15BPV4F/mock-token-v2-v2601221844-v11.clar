(define-constant ERR-UNAUTHORIZED u100)
(define-constant ERR-INSUFFICIENT u101)

(define-data-var owner principal tx-sender)
(define-data-var total-supply uint u0)

(define-map balances
  { user: principal }
  { balance: uint }
)

(define-read-only (get-name) "Mock Token")
(define-read-only (get-symbol) "MOCK")
(define-read-only (get-decimals) u6)
(define-read-only (get-total-supply) (var-get total-supply))

(define-read-only (get-balance (user principal))
  (get balance (default-to { balance: u0 } (map-get? balances { user: user })))
)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (let ((sender-entry (default-to { balance: u0 } (map-get? balances { user: sender }))))
    (begin
      (asserts! (is-eq tx-sender sender) (err ERR-UNAUTHORIZED))
      (asserts! (>= (get balance sender-entry) amount) (err ERR-INSUFFICIENT))
      (map-set balances { user: sender } { balance: (- (get balance sender-entry) amount) })
      (map-set balances { user: recipient }
        { balance: (+ (get balance (default-to { balance: u0 } (map-get? balances { user: recipient }))) amount) }
      )
      (ok true)
    )
  )
)

(define-public (mint (recipient principal) (amount uint))
  (let ((entry (default-to { balance: u0 } (map-get? balances { user: recipient }))))
    (begin
      (asserts! (is-eq tx-sender (var-get owner)) (err ERR-UNAUTHORIZED))
      (map-set balances { user: recipient } { balance: (+ (get balance entry) amount) })
      (var-set total-supply (+ (var-get total-supply) amount))
      (ok true)
    )
  )
)
