;; vault-stack Contract
;; Demonstrates Clarity 4's stacks-block-height feature
;; Users can deposit STX and earn interest based on actual time locked

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u101))
(define-constant err-vault-locked (err u102))
(define-constant err-vault-not-found (err u103))
(define-constant err-invalid-duration (err u104))
(define-constant err-invalid-amount (err u105))
(define-constant err-already-withdrawn (err u106))

;; Annual interest rate (in basis points: 500 = 5%)
(define-constant annual-interest-rate u500)

;; Minimum lock duration (7 days in seconds)
(define-constant min-lock-duration u604800)

;; Data Variables
(define-data-var total-deposits uint u0)
(define-data-var vault-counter uint u0)

;; Data Maps
(define-map vaults
  { vault-id: uint }
  {
    owner: principal,
    amount: uint,
    deposit-time: uint,
    unlock-time: uint,
    interest-earned: uint,
    withdrawn: bool
  }
)

(define-map user-vault-ids
  { user: principal }
  { vault-ids: (list 50 uint) }
)

;; Read-only functions

(define-read-only (get-vault (vault-id uint))
  (map-get? vaults { vault-id: vault-id })
)

(define-read-only (get-user-vaults (user principal))
  (default-to 
    { vault-ids: (list) }
    (map-get? user-vault-ids { user: user })
  )
)

(define-read-only (get-total-deposits)
  (ok (var-get total-deposits))
)

(define-read-only (get-vault-counter)
  (ok (var-get vault-counter))
)

(define-read-only (calculate-interest (amount uint) (duration uint))
  (let
    (
      ;; Convert duration from seconds to years (simplified: 365 days)
      (seconds-per-year u31536000)
      ;; Calculate interest: (amount * rate * duration) / (10000 * seconds_per_year)
      ;; We use 10000 as denominator because rate is in basis points
      (interest (/ (* (* amount annual-interest-rate) duration) 
                   (* u10000 seconds-per-year)))
    )
    (ok interest)
  )
)

(define-read-only (get-vault-status (vault-id uint))
  (match (get-vault vault-id)
    vault
    (let
      (
        (current-time stacks-block-height)
        (is-unlocked (>= current-time (get unlock-time vault)))
        (time-remaining (if is-unlocked u0 (- (get unlock-time vault) current-time)))
      )
      (ok {
        vault-id: vault-id,
        owner: (get owner vault),
        amount: (get amount vault),
        deposit-time: (get deposit-time vault),
        unlock-time: (get unlock-time vault),
        current-time: current-time,
        is-unlocked: is-unlocked,
        time-remaining: time-remaining,
        interest-earned: (get interest-earned vault),
        withdrawn: (get withdrawn vault)
      })
    )
    err-vault-not-found
  )
)

(define-read-only (get-current-time)
  (ok stacks-block-height)
)

;; Private functions

(define-private (add-vault-to-user (user principal) (vault-id uint))
  (let
    (
      (current-vaults (get vault-ids (get-user-vaults user)))
      (updated-vaults (unwrap-panic (as-max-len? (append current-vaults vault-id) u50)))
    )
    (map-set user-vault-ids
      { user: user }
      { vault-ids: updated-vaults }
    )
  )
)

;; Public functions

(define-public (create-vault (amount uint) (lock-duration uint))
  (let
    (
      (vault-id (+ (var-get vault-counter) u1))
      (deposit-time stacks-block-height)
      (unlock-time (+ stacks-block-height lock-duration))
      (interest (unwrap! (calculate-interest amount lock-duration) err-invalid-amount))
    )
    ;; Validations
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= lock-duration min-lock-duration) err-invalid-duration)
    
    ;; Transfer STX from user to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Create vault record
    (map-set vaults
      { vault-id: vault-id }
      {
        owner: tx-sender,
        amount: amount,
        deposit-time: deposit-time,
        unlock-time: unlock-time,
        interest-earned: interest,
        withdrawn: false
      }
    )
    
    ;; Update tracking variables
    (var-set vault-counter vault-id)
    (var-set total-deposits (+ (var-get total-deposits) amount))
    (add-vault-to-user tx-sender vault-id)
    
    (ok vault-id)
  )
)

(define-public (withdraw-from-vault (vault-id uint))
  (let
    (
      (vault (unwrap! (get-vault vault-id) err-vault-not-found))
      (current-time stacks-block-height)
    )
    ;; Validations
    (asserts! (is-eq tx-sender (get owner vault)) err-owner-only)
    (asserts! (not (get withdrawn vault)) err-already-withdrawn)
    (asserts! (>= current-time (get unlock-time vault)) err-vault-locked)
    
    ;; Calculate total withdrawal (principal + interest)
    (let
      (
        (principal-amount (get amount vault))
        (interest-amount (get interest-earned vault))
        (total-amount (+ principal-amount interest-amount))
      )
      ;; Transfer STX back to user (using as-contract to send from contract)
      (try! (as-contract (stx-transfer? total-amount tx-sender (get owner vault))))
      
      ;; Mark vault as withdrawn
      (map-set vaults
        { vault-id: vault-id }
        (merge vault { withdrawn: true })
      )
      
      ;; Update total deposits
      (var-set total-deposits (- (var-get total-deposits) principal-amount))
      
      (ok total-amount)
    )
  )
)

(define-public (emergency-withdraw (vault-id uint))
  (let
    (
      (vault (unwrap! (get-vault vault-id) err-vault-not-found))
    )
    ;; Validations
    (asserts! (is-eq tx-sender (get owner vault)) err-owner-only)
    (asserts! (not (get withdrawn vault)) err-already-withdrawn)
    
    ;; Early withdrawal forfeits interest, only returns principal
    (let
      (
        (principal-amount (get amount vault))
      )
      ;; Transfer only principal back to user
      (try! (as-contract (stx-transfer? principal-amount tx-sender (get owner vault))))
      
      ;; Mark vault as withdrawn
      (map-set vaults
        { vault-id: vault-id }
        (merge vault { withdrawn: true })
      )
      
      ;; Update total deposits
      (var-set total-deposits (- (var-get total-deposits) principal-amount))
      
      (ok principal-amount)
    )
  )
)

;; Admin functions for contract owner

(define-public (fund-contract (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (stx-transfer? amount tx-sender (as-contract tx-sender))
  )
)

(define-read-only (get-contract-balance)
  (ok (stx-get-balance (as-contract tx-sender)))
)