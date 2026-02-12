;; xWallet - Simple Custodial STX Wallet Contract

;; Error constants
(define-constant ERR-INSUFFICIENT-BALANCE (err u100))
(define-constant ERR-ZERO-AMOUNT (err u101))
(define-constant ERR-SELF-SEND (err u102))
(define-constant ERR-TRANSFER-FAILED (err u103))

;; Data maps
(define-map balances principal uint)

;; Private helper: get balance or default to 0
(define-private (get-balance-or-default (user principal))
  (default-to u0 (map-get? balances user))
)

;; Read-only: get user balance
(define-read-only (get-balance (user principal))
  (ok (get-balance-or-default user))
)

;; Public: deposit STX into the contract
(define-public (deposit (amount uint))
  (let
    (
      (sender tx-sender)
      (current-balance (get-balance-or-default sender))
    )
    ;; Check for zero amount
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    
    ;; Transfer STX from sender to contract BEFORE updating balance
    (match (stx-transfer? amount sender contract-caller)
      success (begin
        ;; Update sender's balance
        (map-set balances sender (+ current-balance amount))
        (ok amount)
      )
      error ERR-TRANSFER-FAILED
    )
  )
)

;; Public: send STX from your balance to another principal
(define-public (send-stx (amount uint) (recipient principal))
  (let
    (
      (sender tx-sender)
      (sender-balance (get-balance-or-default sender))
    )
    ;; Check for zero amount
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    
    ;; Prevent self-send (use withdraw instead)
    (asserts! (not (is-eq sender recipient)) ERR-SELF-SEND)
    
    ;; Check sufficient balance
    (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
    
    ;; Transfer STX from contract to recipient BEFORE updating balances
    (try! (stx-transfer? amount tx-sender recipient))
    
    ;; Deduct from sender's balance
    (map-set balances sender (- sender-balance amount))
    ;; Add to recipient's balance
    (map-set balances recipient (+ (get-balance-or-default recipient) amount))
    (ok amount)
  )
)

;; Public: withdraw STX from your balance back to your address
(define-public (withdraw (amount uint))
  (let
    (
      (sender tx-sender)
      (sender-balance (get-balance-or-default sender))
    )
    ;; Check for zero amount
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    
    ;; Check sufficient balance
    (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
    
    ;; Transfer STX from contract to sender BEFORE updating balance
    (try! (stx-transfer? amount tx-sender sender))
    
    ;; Deduct from sender's balance
    (map-set balances sender (- sender-balance amount))
    (ok amount)
  )
)