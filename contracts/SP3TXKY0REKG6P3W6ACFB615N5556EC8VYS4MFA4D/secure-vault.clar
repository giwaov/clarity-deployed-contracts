;; savings-vault.clar
;; Personal savings vault with goals and interest

;; Constants
(define-constant CONTRACT-ADDRESS .savings-vault)
(define-constant ERR-INSUFFICIENT-BALANCE (err u100))
(define-constant ERR-ZERO-AMOUNT (err u101))

;; Data Variables
(define-data-var total-vault-balance uint u0)

;; Maps
(define-map user-balances principal uint)
(define-map savings-goals { user: principal, name: (string-ascii 64) }
  {
    target: uint,
    deadline: uint,
    achieved: bool
  }
)

;; Public Functions
(define-public (deposit (amount uint))
  (let (
    (current-balance (default-to u0 (map-get? user-balances tx-sender)))
  )
    (begin
      (asserts! (> amount u0) ERR-ZERO-AMOUNT)
      (unwrap-panic (stx-transfer? amount tx-sender CONTRACT-ADDRESS))
      
      (map-set user-balances tx-sender (+ current-balance amount))
      (var-set total-vault-balance (+ (var-get total-vault-balance) amount))
      (ok true)
    )
  )
)

(define-public (withdraw (amount uint))
  (let (
    (current-balance (default-to u0 (map-get? user-balances tx-sender)))
  )
    (begin
      (asserts! (>= current-balance amount) ERR-INSUFFICIENT-BALANCE)
      (map-set user-balances tx-sender (- current-balance amount))
      (var-set total-vault-balance (- (var-get total-vault-balance) amount))
      (try! (stx-transfer? amount CONTRACT-ADDRESS tx-sender))
      (ok true)
    )
  )
)

(define-public (create-goal (name (string-ascii 64)) (target uint) (duration-days uint))
  (begin
    (asserts! (> (len name) u0) (err u103))
    (asserts! (> target u0) ERR-ZERO-AMOUNT)
    (asserts! (> duration-days u0) (err u104))
    (ok (map-set savings-goals { user: tx-sender, name: name } {
      target: target,
      deadline: (+ stacks-block-time (* duration-days u86400)),
      achieved: false
    }))
  )
)

;; Read-only
(define-read-only (get-balance (user principal))
  (default-to u0 (map-get? user-balances user))
)

(define-read-only (get-goal (user principal) (name (string-ascii 64)))
  (map-get? savings-goals { user: user, name: name })
)
