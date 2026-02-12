---
title: "Trait bithodl-savings"
draft: true
---
```
(define-fungible-token bithodl-stx)
(define-fungible-token bithodl-sbtc)

(define-constant ERR_INSUFFICIENT_BALANCE (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_NOT_OWNER (err u102))
(define-constant ERR_NO_BITHODL_PLAN (err u103))
(define-constant ERR_INVALID_FREQUENCY (err u104))
(define-constant ERR_WITHDRAWAL_TOO_SOON (err u105))
(define-constant ERR_UNAUTHORIZED_ACCESS (err u106))
(define-constant ERR_ALREADY_HAS_PLAN (err u107))

(define-data-var contract-owner principal tx-sender)

(define-data-var total-stx-deposited uint u0)
(define-data-var total-sbtc-deposited uint u0)
(define-data-var total-users uint u0)

(define-map bithodl-plans
  principal
  {
    target-amount: uint,
    frequency: uint,
    next-purchase-block: uint,
    auto-purchase-enabled: bool,
    created-at: uint
  }
)

(define-map stx-balances
  principal
  uint
)

(define-map sbtc-balances
  principal
  uint
)

(define-map transaction-history
  {
    user: principal,
    tx-id: uint
  }
  {
    tx-type: uint,
    amount: uint,
    token-type: uint,
    timestamp: uint,
    block-height-placeholder: uint,
    memo: (string-ascii 100)
  }
)

(define-map next-transaction-id
  principal
  uint
)

(define-map user-total-deposits
  principal
  uint
)

(define-map user-total-withdrawals
  principal
  uint
)

(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

(define-read-only (get-total-stx-deposited)
  (var-get total-stx-deposited)
)

(define-read-only (get-total-sbtc-deposited)
  (var-get total-sbtc-deposited)
)

(define-read-only (get-total-users)
  (var-get total-users)
)

(define-read-only (get-user-stx-balance (user principal))
  (default-to u0 (map-get? stx-balances user))
)

(define-read-only (get-user-sbtc-balance (user principal))
  (default-to u0 (map-get? sbtc-balances user))
)

(define-read-only (get-user-bithodl-plan (user principal))
  (map-get? bithodl-plans user)
)

(define-read-only (get-user-total-deposits (user principal))
  (default-to u0 (map-get? user-total-deposits user))
)

(define-read-only (get-user-total-withdrawals (user principal))
  (default-to u0 (map-get? user-total-withdrawals user))
)

(define-read-only (get-user-transaction-history (user principal) (offset uint) (limit uint))
  (ok (list))
)

(define-read-only (has-bithodl-plan (user principal))
  (match (map-get? bithodl-plans user)
    plan true
    false
  )
)

(define-read-only (get-blocks-until-next-purchase (user principal))
  (match (map-get? bithodl-plans user)
    plan
      (if (>= u0 (get next-purchase-block plan))
        u0
        (- (get next-purchase-block plan) u0)
      )
    u0
  )
)

(define-read-only (get-user-balance (user principal))
  (let (
    (stx-balance (default-to u0 (map-get? stx-balances user)))
    (sbtc-balance (default-to u0 (map-get? sbtc-balances user)))
  )
    {
      stx-balance: stx-balance,
      sbtc-balance: sbtc-balance
    }
  )
)

(define-read-only (get-user-bithodl-plan-details (user principal))
  (match (map-get? bithodl-plans user)
    plan
      {
        target-amount: (get target-amount plan),
        frequency: (get frequency plan),
        next-purchase-block: (get next-purchase-block plan),
        auto-purchase-enabled: (get auto-purchase-enabled plan),
        created-at: (get created-at plan),
        is-active: true
      }
    {
      target-amount: u0,
      frequency: u0,
      next-purchase-block: u0,
      auto-purchase-enabled: false,
      created-at: u0,
      is-active: false
    }
  )
)

(define-read-only (calculate-next-execution-block (user principal))
  (match (map-get? bithodl-plans user)
    plan
      (if (get auto-purchase-enabled plan)
        (get next-purchase-block plan)
        u0
      )
    u0
  )
)

(define-read-only (get-user-total-saved (user principal))
  (let (
    (stx-balance (default-to u0 (map-get? stx-balances user)))
    (sbtc-balance (default-to u0 (map-get? sbtc-balances user)))
  )
    (+ stx-balance sbtc-balance)
  )
)

(define-read-only (is-bithodl-plan-active (user principal))
  (match (map-get? bithodl-plans user)
    plan
      (and
        (get auto-purchase-enabled plan)
        (>= u0 (get created-at plan))
      )
    false
  )
)

(define-public (create-bithodl-plan (target-amount uint) (frequency uint))
  (begin
    (asserts! (> target-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> frequency u0) ERR_INVALID_FREQUENCY)
    (asserts! (< target-amount u100000000000) ERR_INVALID_AMOUNT)
    
    (asserts! (is-none (map-get? bithodl-plans tx-sender)) ERR_ALREADY_HAS_PLAN)
    
    (let (
      (new-plan {
        target-amount: target-amount,
        frequency: frequency,
        next-purchase-block: (+ u0 frequency),
        auto-purchase-enabled: true,
        created-at: u0
      })
    )
      (map-set bithodl-plans tx-sender new-plan)
      
      (if (is-eq (default-to u0 (map-get? stx-balances tx-sender)) u0)
        (var-set total-users (+ (var-get total-users) u1))
        (var-set total-users (var-get total-users))
      )
      
      (ok true)
    )
  )
)

(define-public (update-bithodl-plan (target-amount uint) (frequency uint))
  (begin
    (asserts! (> target-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> frequency u0) ERR_INVALID_FREQUENCY)
    (asserts! (< target-amount u100000000000) ERR_INVALID_AMOUNT)
    
    (asserts! (is-some (map-get? bithodl-plans tx-sender)) ERR_NO_BITHODL_PLAN)
    
    (let (
      (current-plan (unwrap! (map-get? bithodl-plans tx-sender) ERR_NO_BITHODL_PLAN))
      (updated-plan {
        target-amount: target-amount,
        frequency: frequency,
        next-purchase-block: (+ u0 frequency),
        auto-purchase-enabled: (get auto-purchase-enabled current-plan),
        created-at: (get created-at current-plan)
      })
    )
      (map-set bithodl-plans tx-sender updated-plan)
      (ok true)
    )
  )
)

(define-public (toggle-auto-purchase)
  (begin
    (asserts! (is-some (map-get? bithodl-plans tx-sender)) ERR_NO_BITHODL_PLAN)
    
    (let (
      (current-plan (unwrap! (map-get? bithodl-plans tx-sender) ERR_NO_BITHODL_PLAN))
      (updated-plan {
        target-amount: (get target-amount current-plan),
        frequency: (get frequency current-plan),
        next-purchase-block: (get next-purchase-block current-plan),
        auto-purchase-enabled: (not (get auto-purchase-enabled current-plan)),
        created-at: (get created-at current-plan)
      })
    )
      (map-set bithodl-plans tx-sender updated-plan)
      (ok true)
    )
  )
)

(define-public (deposit-stx (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    ;; Note: Removed balance check for MVP - we're just tracking balances
    (asserts! (< amount u100000000000) ERR_INVALID_AMOUNT)
    
    (let (
      (current-balance (default-to u0 (map-get? stx-balances tx-sender)))
      (new-balance (+ current-balance amount))
      (total-deposits (default-to u0 (map-get? user-total-deposits tx-sender)))
      (new-total-deposits (+ total-deposits amount))
    )
      (map-set stx-balances tx-sender new-balance)
      (map-set user-total-deposits tx-sender new-total-deposits)
      (var-set total-stx-deposited (+ (var-get total-stx-deposited) amount))
      
      (record-transaction tx-sender u1 amount u1 "STX deposit")
      
      ;; MVP: Just tracking balances, no actual STX transfer
      (ok true)
    )
  )
)

(define-public (deposit-sbtc (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (< amount u100000000000) ERR_INVALID_AMOUNT)
    
    (let (
      (current-balance (default-to u0 (map-get? sbtc-balances tx-sender)))
      (new-balance (+ current-balance amount))
      (total-deposits (default-to u0 (map-get? user-total-deposits tx-sender)))
      (new-total-deposits (+ total-deposits amount))
    )
      (map-set sbtc-balances tx-sender new-balance)
      (map-set user-total-deposits tx-sender new-total-deposits)
      (var-set total-sbtc-deposited (+ (var-get total-sbtc-deposited) amount))
      
      (record-transaction tx-sender u1 amount u2 "sBTC deposit")
      
      (ok true)
    )
  )
)

(define-public (withdraw-stx (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (< amount u100000000000) ERR_INVALID_AMOUNT)
    
    (let (
      (current-balance (default-to u0 (map-get? stx-balances tx-sender)))
    )
      (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
      
      (let (
        (new-balance (- current-balance amount))
        (total-withdrawals (default-to u0 (map-get? user-total-withdrawals tx-sender)))
        (new-total-withdrawals (+ total-withdrawals amount))
      )
        (if (is-eq new-balance u0)
          (map-delete stx-balances tx-sender)
          (map-set stx-balances tx-sender new-balance)
        )
        
        (map-set user-total-withdrawals tx-sender new-total-withdrawals)
        (var-set total-stx-deposited (- (var-get total-stx-deposited) amount))
        
        (record-transaction tx-sender u2 amount u1 "STX withdrawal")
        
        ;; MVP: Just tracking balances, no actual STX transfer
        (ok true)
      )
    )
  )
)

(define-public (withdraw-sbtc (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (< amount u100000000000) ERR_INVALID_AMOUNT)
    
    (let (
      (current-balance (default-to u0 (map-get? sbtc-balances tx-sender)))
    )
      (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
      
      (let (
        (new-balance (- current-balance amount))
        (total-withdrawals (default-to u0 (map-get? user-total-withdrawals tx-sender)))
        (new-total-withdrawals (+ total-withdrawals amount))
      )
        (if (is-eq new-balance u0)
          (map-delete sbtc-balances tx-sender)
          (map-set sbtc-balances tx-sender new-balance)
        )
        
        (map-set user-total-withdrawals tx-sender new-total-withdrawals)
        (var-set total-sbtc-deposited (- (var-get total-sbtc-deposited) amount))
        
        (record-transaction tx-sender u2 amount u2 "sBTC withdrawal")
        
        (ok true)
      )
    )
  )
)

(define-public (execute-auto-purchase)
  (begin
    (asserts! (is-some (map-get? bithodl-plans tx-sender)) ERR_NO_BITHODL_PLAN)
    
    (let (
      (plan (unwrap! (map-get? bithodl-plans tx-sender) ERR_NO_BITHODL_PLAN))
    )
      (asserts! (get auto-purchase-enabled plan) ERR_UNAUTHORIZED_ACCESS)
      (asserts! (>= u0 (get next-purchase-block plan)) ERR_WITHDRAWAL_TOO_SOON)
      
      (let (
        (purchase-amount (/ (get target-amount plan) (get frequency plan)))
        (current-stx-balance (default-to u0 (map-get? stx-balances tx-sender)))
      )
        (asserts! (>= current-stx-balance purchase-amount) ERR_INSUFFICIENT_BALANCE)
        
        (let (
          (new-stx-balance (- current-stx-balance purchase-amount))
          (current-sbtc-balance (default-to u0 (map-get? sbtc-balances tx-sender)))
          (sbtc-amount (/ purchase-amount u1000000))
          (new-sbtc-balance (+ current-sbtc-balance sbtc-amount))
        )
          (map-set stx-balances tx-sender new-stx-balance)
          (map-set sbtc-balances tx-sender new-sbtc-balance)
          
          (map-set bithodl-plans tx-sender {
            target-amount: (get target-amount plan),
            frequency: (get frequency plan),
            next-purchase-block: (+ u0 (get frequency plan)),
            auto-purchase-enabled: (get auto-purchase-enabled plan),
            created-at: (get created-at plan)
          })
          
          (record-transaction tx-sender u3 purchase-amount u1 "Auto-purchase STX to sBTC")
          
          (ok true)
        )
      )
    )
  )
)

(define-private (record-transaction (user principal) (tx-type uint) (amount uint) (token-type uint) (memo (string-ascii 100)))
  (let (
    (current-tx-id (default-to u1 (map-get? next-transaction-id user)))
    (new-tx-id (+ current-tx-id u1))
  )
    (map-set transaction-history {user: user, tx-id: current-tx-id} {
      tx-type: tx-type,
      amount: amount,
      token-type: token-type,
      timestamp: u0,
      block-height-placeholder: u0,
      memo: memo
    })
    (map-set next-transaction-id user new-tx-id)
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_OWNER)
    (var-set contract-owner new-owner)
    (ok true)
  )
)
```
