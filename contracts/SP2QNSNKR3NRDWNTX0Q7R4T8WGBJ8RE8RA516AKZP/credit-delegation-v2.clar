;; Credit Delegation Contract
;; Lend your reputation to trusted parties and earn fees

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u700))
(define-constant err-not-found (err u701))
(define-constant err-unauthorized (err u702))
(define-constant err-insufficient-credit (err u703))
(define-constant err-already-delegated (err u704))
(define-constant err-delegation-expired (err u705))

;; Default delegation fee: 10%
(define-constant default-delegation-fee u1000)

;; Data Variables
(define-data-var delegation-nonce uint u0)

;; Data Maps
(define-map credit-delegations
  { delegation-id: uint }
  {
    delegator: principal,
    delegatee: principal,
    credit-limit: uint,
    used-credit: uint,
    fee-rate: uint,
    start-block: uint,
    end-block: uint,
    active: bool
  }
)

(define-map delegator-stats
  { delegator: principal }
  {
    total-delegated: uint,
    active-delegations: uint,
    fees-earned: uint,
    defaults: uint
  }
)

(define-map delegatee-stats
  { delegatee: principal }
  {
    total-borrowed: uint,
    active-borrows: uint,
    total-repaid: uint,
    defaults: uint
  }
)

(define-map active-delegation
  { delegator: principal, delegatee: principal }
  { delegation-id: uint, active: bool }
)

;; Read-only functions
(define-read-only (get-delegation (delegation-id uint))
  (map-get? credit-delegations { delegation-id: delegation-id })
)

(define-read-only (get-delegator-stats (delegator principal))
  (default-to
    { total-delegated: u0, active-delegations: u0, fees-earned: u0, defaults: u0 }
    (map-get? delegator-stats { delegator: delegator })
  )
)

(define-read-only (get-delegatee-stats (delegatee principal))
  (default-to
    { total-borrowed: u0, active-borrows: u0, total-repaid: u0, defaults: u0 }
    (map-get? delegatee-stats { delegatee: delegatee })
  )
)

(define-read-only (get-available-credit (delegation-id uint))
  (let
    (
      (delegation (unwrap! (get-delegation delegation-id) (err err-not-found)))
    )
    (ok (- (get credit-limit delegation) (get used-credit delegation)))
  )
)

(define-read-only (has-active-delegation (delegator principal) (delegatee principal))
  (default-to false
    (get active (map-get? active-delegation { delegator: delegator, delegatee: delegatee })))
)

;; Public functions

;; Delegate credit to another user
(define-public (delegate-credit
  (delegatee principal)
  (credit-limit uint)
  (fee-rate uint)
  (duration uint))
  (let
    (
      (delegation-id (var-get delegation-nonce))
    )
    (asserts! (not (has-active-delegation tx-sender delegatee)) err-already-delegated)
    (asserts! (> credit-limit u0) err-insufficient-credit)
    
    ;; Create delegation
    (map-set credit-delegations
      { delegation-id: delegation-id }
      {
        delegator: tx-sender,
        delegatee: delegatee,
        credit-limit: credit-limit,
        used-credit: u0,
        fee-rate: fee-rate,
        start-block: stacks-block-height,
        end-block: (+ stacks-block-height duration),
        active: true
      }
    )
    
    ;; Mark as active
    (map-set active-delegation
      { delegator: tx-sender, delegatee: delegatee }
      { delegation-id: delegation-id, active: true }
    )
    
    ;; Update delegator stats
    (let
      (
        (stats (get-delegator-stats tx-sender))
      )
      (map-set delegator-stats
        { delegator: tx-sender }
        {
          total-delegated: (+ (get total-delegated stats) credit-limit),
          active-delegations: (+ (get active-delegations stats) u1),
          fees-earned: (get fees-earned stats),
          defaults: (get defaults stats)
        }
      )
    )
    
    (var-set delegation-nonce (+ delegation-id u1))
    (ok delegation-id)
  )
)

;; Borrow using delegated credit
(define-public (borrow-delegated-credit
  (delegation-id uint)
  (amount uint))
  (let
    (
      (delegation (unwrap! (get-delegation delegation-id) err-not-found))
      (available (unwrap! (get-available-credit delegation-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get delegatee delegation)) err-unauthorized)
    (asserts! (get active delegation) err-delegation-expired)
    (asserts! (<= stacks-block-height (get end-block delegation)) err-delegation-expired)
    (asserts! (<= amount available) err-insufficient-credit)
    
    ;; Update used credit
    (map-set credit-delegations
      { delegation-id: delegation-id }
      (merge delegation { used-credit: (+ (get used-credit delegation) amount) })
    )
    
    ;; Update delegatee stats
    (let
      (
        (stats (get-delegatee-stats tx-sender))
      )
      (map-set delegatee-stats
        { delegatee: tx-sender }
        {
          total-borrowed: (+ (get total-borrowed stats) amount),
          active-borrows: (+ (get active-borrows stats) u1),
          total-repaid: (get total-repaid stats),
          defaults: (get defaults stats)
        }
      )
    )
    
    (ok amount)
  )
)

;; Repay delegated credit
(define-public (repay-delegated-credit
  (delegation-id uint)
  (amount uint))
  (let
    (
      (delegation (unwrap! (get-delegation delegation-id) err-not-found))
      (fee (/ (* amount (get fee-rate delegation)) u10000))
      (principal-repayment (- amount fee))
    )
    (asserts! (is-eq tx-sender (get delegatee delegation)) err-unauthorized)
    (asserts! (<= amount (get used-credit delegation)) err-insufficient-credit)
    
    ;; Transfer fee to delegator
    (try! (stx-transfer? fee tx-sender (get delegator delegation)))
    
    ;; Update used credit
    (map-set credit-delegations
      { delegation-id: delegation-id }
      (merge delegation { used-credit: (- (get used-credit delegation) principal-repayment) })
    )
    
    ;; Update delegator stats (fees earned)
    (let
      (
        (stats (get-delegator-stats (get delegator delegation)))
      )
      (map-set delegator-stats
        { delegator: (get delegator delegation) }
        (merge stats { fees-earned: (+ (get fees-earned stats) fee) })
      )
    )
    
    ;; Update delegatee stats
    (let
      (
        (stats (get-delegatee-stats tx-sender))
      )
      (map-set delegatee-stats
        { delegatee: tx-sender }
        {
          total-borrowed: (get total-borrowed stats),
          active-borrows: (- (get active-borrows stats) u1),
          total-repaid: (+ (get total-repaid stats) principal-repayment),
          defaults: (get defaults stats)
        }
      )
    )
    
    (ok { repaid: principal-repayment, fee: fee })
  )
)

;; Revoke credit delegation
(define-public (revoke-delegation (delegation-id uint))
  (let
    (
      (delegation (unwrap! (get-delegation delegation-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get delegator delegation)) err-unauthorized)
    (asserts! (is-eq (get used-credit delegation) u0) err-insufficient-credit)
    
    ;; Deactivate delegation
    (map-set credit-delegations
      { delegation-id: delegation-id }
      (merge delegation { active: false })
    )
    
    ;; Remove from active
    (map-set active-delegation
      { delegator: (get delegator delegation), delegatee: (get delegatee delegation) }
      { delegation-id: delegation-id, active: false }
    )
    
    ;; Update delegator stats
    (let
      (
        (stats (get-delegator-stats tx-sender))
      )
      (map-set delegator-stats
        { delegator: tx-sender }
        (merge stats { active-delegations: (- (get active-delegations stats) u1) })
      )
    )
    
    (ok true)
  )
)

;; Record default (called by core contract)
(define-public (record-delegation-default (delegation-id uint))
  (let
    (
      (delegation (unwrap! (get-delegation delegation-id) err-not-found))
      (delegator (get delegator delegation))
    )
    ;; Update delegator stats
    (let
      (
        (stats (get-delegator-stats delegator))
      )
      (map-set delegator-stats
        { delegator: delegator }
        (merge stats { defaults: (+ (get defaults stats) u1) })
      )
    )
    
    ;; Update delegatee stats
    (let
      (
        (delegatee (get delegatee delegation))
        (stats (get-delegatee-stats delegatee))
      )
      (map-set delegatee-stats
        { delegatee: delegatee }
        (merge stats { defaults: (+ (get defaults stats) u1) })
      )
    )
    
    (ok true)
  )
)
