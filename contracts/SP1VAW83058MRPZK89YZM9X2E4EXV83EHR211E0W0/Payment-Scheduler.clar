;; TimeVault - Decentralized Time-Locked STX Escrow Protocol Contract
;;
;; Clarity Version: 4
;; Epoch: 3.3
;;
;; TimeVault enables users to schedule future STX transfers with automatic execution
;; at predetermined block heights. This trustless escrow system supports delayed payments,
;; automated savings plans, and treasury management.

;; Error codes for operation failures
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-INVALID-TARGET-BLOCK (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-TRANSFER-NOT-FOUND (err u103))
(define-constant ERR-ALREADY-EXECUTED (err u104))
(define-constant ERR-EXECUTION-TOO-EARLY (err u105))
(define-constant ERR-TRANSFER-FAILURE (err u106))
(define-constant ERR-INVALID-RECIPIENT (err u107))

;; Minimum blocks required between scheduling and execution
(define-constant min-blocks-before-execution u1)

;; Service Fee: 5% (Basis points: 500) - High fees to attract protocol revenue
(define-constant SERVICE-FEE-BPS u500)
(define-constant BPS-DENOMINATOR u10000)

;; Principal authorized to perform administrative operations
(define-data-var admin-principal principal tx-sender)

;; Sequential identifier for tracking all transfers
(define-data-var transfer-id-counter uint u0)

;; Accumulated Fees
(define-data-var accumulated-fees uint u0)

;; Core storage for scheduled transfer details
(define-map scheduled-transfers
  { id: uint }
  {
    sender: principal,
    recipient: principal,
    amount: uint,
    fee-paid: uint,
    unlock-at-block: uint,
    is-completed: bool,
  }
)

;; Creates a new time-locked STX transfer with Fees
(define-public (create-scheduled-transfer
    (recipient principal)
    (transfer-amount uint)
    (delay-blocks uint)
  )
  (let (
      (caller tx-sender)
      (new-id (var-get transfer-id-counter))
      (execution-block (+ stacks-block-height delay-blocks))
      (fee-amount (/ (* transfer-amount SERVICE-FEE-BPS) BPS-DENOMINATOR))
      (total-amount (+ transfer-amount fee-amount))
    )
    (asserts! (> transfer-amount u0) ERR-INSUFFICIENT-BALANCE)

    ;; Transfer Total Amount (Principal + Fee) to Contract
    ;; 'as-contract' is NOT used here because user is sending TO contract.
    (try! (stx-transfer? total-amount caller (as-contract tx-sender)))

    (map-set scheduled-transfers { id: new-id } {
      sender: caller,
      recipient: recipient,
      amount: transfer-amount,
      fee-paid: fee-amount,
      unlock-at-block: execution-block,
      is-completed: false,
    })

    (var-set transfer-id-counter (+ new-id u1))
    (var-set accumulated-fees (+ (var-get accumulated-fees) fee-amount))
    (ok new-id)
  )
)

;; Executes a matured time-locked transfer
(define-public (execute-transfer (id uint))
  (let (
      (transfer-data (unwrap! (map-get? scheduled-transfers { id: id }) ERR-TRANSFER-NOT-FOUND))
      (recipient-address (get recipient transfer-data))
      (locked-amount (get amount transfer-data))
      (already-completed (get is-completed transfer-data))
      (unlock-block (get unlock-at-block transfer-data))
    )
    (asserts! (not already-completed) ERR-ALREADY-EXECUTED)
    (asserts! (>= stacks-block-height unlock-block) ERR-EXECUTION-TOO-EARLY)

    ;; Transfer locked amount to recipient from contract
    ;; Transfer locked amount to recipient from contract
    ;; Using as-contract to switch context to contract principal
    (try! (as-contract (stx-transfer? locked-amount tx-sender recipient-address)))

    (map-set scheduled-transfers { id: id }
      (merge transfer-data { is-completed: true })
    )
    (ok true)
  )
)
