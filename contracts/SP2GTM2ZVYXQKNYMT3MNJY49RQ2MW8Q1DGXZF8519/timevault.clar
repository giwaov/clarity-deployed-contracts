;; title: simple-vault
;; summary: Lock STX until a specific block height is reached.

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-TOO-EARLY (err u402))
(define-constant ERR-NO-DEPOSIT (err u404))

;; Data Maps
;; Stores how much each user has locked and when it unlocks
(define-map Vaults
  principal
  { amount: uint, unlock-height: uint }
)

;; Public Functions

;; Deposit STX into the vault
;; @param amount: uint - amount in micro-STX
;; @param lock-duration: uint - how many blocks from now to lock
(define-public (deposit (amount uint) (lock-duration uint))
  (let
    (
      (current-vault (default-to { amount: u0, unlock-height: u0 } (map-get? Vaults tx-sender)))
      (new-amount (+ (get amount current-vault) amount))
      (target-height (+ burn-block-height lock-duration))
    )
    (begin
      ;; Transfer STX from user to the contract
      (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      ;; Update the map with the new total and the latest lock height
      (map-set Vaults tx-sender { amount: new-amount, unlock-height: target-height })
      (ok true)
    )
  )
)

;; Withdraw everything once the time has passed
(define-public (withdraw)
  (let
    (
      (vault (unwrap! (map-get? Vaults tx-sender) ERR-NO-DEPOSIT))
      (amount (get amount vault))
      (unlock-height (get unlock-height vault))
    )
    (begin
      ;; Check if the current Bitcoin block height has passed the unlock height
      (asserts! (>= burn-block-height unlock-height) ERR-TOO-EARLY)
      ;; Clear the vault first to prevent re-entrancy (best practice)
      (map-delete Vaults tx-sender)
      ;; Send the STX back to the user
      (as-contract (stx-transfer? amount (as-contract tx-sender) tx-sender))
    )
  )
)

;; Read-Only Functions

;; Check your current balance and unlock height
(define-read-only (get-vault-info (user principal))
  (map-get? Vaults user)
)
