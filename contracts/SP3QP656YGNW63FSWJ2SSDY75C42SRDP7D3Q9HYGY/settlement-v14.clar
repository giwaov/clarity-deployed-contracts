;; Settlement V3 - Works with vault-v3 and multi-currency-oracle
;; Backend handles currency conversions via swap-router
;;
;; FLOW:
;; 1. After expiry, backend calls settle-contract
;; 2. Contract determines winners based on BTC price vs strike
;; 3. Winners call claim-payout (via backend)
;; 4. Contract sends sBTC to backend
;; 5. Backend reads payment-currency and swaps if needed
;; 6. Backend sends original currency to user

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u300))
(define-constant err-not-found (err u301))
(define-constant err-not-expired (err u302))
(define-constant err-already-settled (err u303))
(define-constant err-no-price (err u304))
(define-constant err-invalid-outcome (err u305))
(define-constant err-already-claimed (err u306))
(define-constant err-not-winner (err u307))

;; Settlement range: $3000 per strike range
(define-constant strike-range-size u300000)  ;; $3000 with 2 decimals

;; Settlement outcomes
(define-map settlement-outcomes
  { contract-id: uint }
  {
    settlement-price: uint,
    settlement-block: uint,
    is-in-money: bool,
    total-winning-positions: uint,
    total-payout-sbtc: uint,
    is-processed: bool
  }
)

;; Winner payouts
(define-map winner-payouts
  { contract-id: uint, user: principal }
  {
    btc-address: (string-ascii 64),  ;; User's Bitcoin address for payouts
    payout-amount-sbtc: uint,
    is-claimed: bool,
    claimed-at: (optional uint)
  }
)

;; Settle an expired contract
(define-public (settle-contract 
    (contract-id uint)
    (btc-price uint))
  (let
    (
      (contract (unwrap! (contract-call? .options-vault-v13 get-contract contract-id) err-invalid-outcome))
      (contract-data (unwrap! contract err-invalid-outcome))
      (strike (get strike-price contract-data))
      (expiry-ts (get expiry-timestamp contract-data))
      (option-type (get option-type contract-data))
      (reward-pool (get reward-pool-sbtc contract-data))
      (rounded-price (unwrap! (contract-call? .multi-currency-oracle-v13 round-to-thousands btc-price) err-no-price))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    ;; Note: Expiry check removed - backend validates expiry before calling
    ;; In production, you could add: (asserts! (>= burn-block-height expiry-block) err-not-expired)
    (asserts! (not (get is-settled contract-data)) err-already-settled)
    
    ;; Determine if contract is in the money
    (let
      (
        (in-the-money (if (is-eq option-type "CALL")
          ;; For CALL: price must be >= strike and < strike + $3000
          (and (>= rounded-price strike) (< rounded-price (+ strike strike-range-size)))
          ;; For PUT: price must be < strike and >= strike - $3000  
          (and (< rounded-price strike) (>= rounded-price (- strike strike-range-size)))
        ))
      )
      
      ;; Store settlement outcome
      (map-set settlement-outcomes
        { contract-id: contract-id }
        {
          settlement-price: rounded-price,
          settlement-block: stacks-block-height,
          is-in-money: in-the-money,
          total-winning-positions: u0,  ;; Will be updated in calculate-payouts
          total-payout-sbtc: reward-pool,
          is-processed: false
        }
      )
      
      ;; Mark contract as settled via options-vault-v4
      (try! (contract-call? .options-vault-v13 deactivate-contract contract-id))
      
      (ok in-the-money)
    )
  )
)

;; Calculate individual winner payout (backend calls this for each winner)
(define-public (calculate-payout
    (contract-id uint)
    (user principal)
    (total-winning-size uint))
  (let
    (
      (position (unwrap! (contract-call? .options-vault-v13 get-position contract-id user) err-not-found))
      (position-data (unwrap! position err-not-found))
      (outcome (unwrap! (map-get? settlement-outcomes { contract-id: contract-id }) err-not-found))
      (user-size (get position-size position-data))
      (user-btc-addr (get btc-address position-data))  ;; Get user's Bitcoin address from position
      (total-pool (get total-payout-sbtc outcome))
      ;; Proportional payout: (user_size / total_size) * pool
      (payout-amount (/ (* total-pool user-size) total-winning-size))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (get is-in-money outcome) err-not-winner)
    
    ;; Store payout data with user's Bitcoin address
    (map-set winner-payouts
      { contract-id: contract-id, user: user }
      {
        btc-address: user-btc-addr,  ;; Store Bitcoin address for payout
        payout-amount-sbtc: payout-amount,
        is-claimed: false,
        claimed-at: none
      }
    )
    
    ;; Update position in vault contract
    (try! (contract-call? .options-vault-v13 update-position-settlement
            contract-id
            user
            true
            payout-amount))
    
    (ok payout-amount)
  )
)

;; Claim payout - Returns sBTC to backend for conversion
(define-public (claim-payout (contract-id uint) (user principal))
  (let
    (
      (payout-data (unwrap! (map-get? winner-payouts { contract-id: contract-id, user: user }) err-not-found))
      (payout-sbtc (get payout-amount-sbtc payout-data))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)  ;; Only backend
    (asserts! (not (get is-claimed payout-data)) err-already-claimed)
    (asserts! (> payout-sbtc u0) err-not-winner)
    
    ;; Transfer sBTC to backend (backend will convert to user's currency)
    ;; Backend reads payment-currency from options-vault.get-position
    (try! (contract-call? .options-vault-v13 claim-payout contract-id user))
    
    ;; Mark as claimed
    (map-set winner-payouts
      { contract-id: contract-id, user: user }
      (merge payout-data {
        is-claimed: true,
        claimed-at: (some stacks-block-height)
      })
    )
    
    (ok payout-sbtc)
  )
)

;; Read-only functions
(define-read-only (get-settlement (contract-id uint))
  (ok (map-get? settlement-outcomes { contract-id: contract-id }))
)

(define-read-only (get-payout-info (contract-id uint) (user principal))
  (ok (map-get? winner-payouts { contract-id: contract-id, user: user }))
)

;; Check if user is a winner (for frontend display)
(define-read-only (is-winner (contract-id uint) (user principal))
  (match (map-get? settlement-outcomes { contract-id: contract-id })
    outcome
      (if (get is-in-money outcome)
        (match (map-get? winner-payouts { contract-id: contract-id, user: user })
          payout (ok (and (> (get payout-amount-sbtc payout) u0) (not (get is-claimed payout))))
          (ok false)
        )
        (ok false)
      )
    (ok false)
  )
)

;; Get settlement info for frontend
(define-read-only (get-settlement-info (contract-id uint))
  (match (map-get? settlement-outcomes { contract-id: contract-id })
    outcome (ok {
      price: (get settlement-price outcome),
      block: (get settlement-block outcome),
      is-in-money: (get is-in-money outcome),
      total-payout: (get total-payout-sbtc outcome)
    })
    err-not-found
  )
)

;; Batch settle up to 100 contracts in ONE transaction
;; NOTE: Simplified version - settles all contracts with same price
;; Returns list of results (true=success, false=failed)
(define-public (settle-contracts-batch
    (contract-ids (list 100 uint))
    (btc-price uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    ;; Fold over contracts, settling each one
    (ok (fold settle-and-accumulate 
              contract-ids 
              {price: btc-price, results: (list)}))
  )
)

;; Helper for fold - settle one contract and accumulate result
(define-private (settle-and-accumulate 
    (contract-id uint)
    (state {price: uint, results: (list 100 bool)}))
  (let
    (
      (result (is-ok (settle-contract contract-id (get price state))))
    )
    {
      price: (get price state),
      results: (unwrap-panic (as-max-len? (append (get results state) result) u100))
    }
  )
)
