---
title: "Trait options-vault-v13"
draft: true
---
```
;; Options Vault V4 - Daily Options with Multi-Currency Support
;; Combines vault grouping + multi-currency tracking (BTC/sBTC/STX)
;;
;; ARCHITECTURE:
;; - Daily vaults: Group strikes by daily expiry (4 PM EST every day)
;; - Batch creation: Create vault + 10-20 strikes in ONE transaction
;; - Multi-currency: Users pay in BTC/sBTC/STX, contract stores in sBTC
;; - Payment tracking: Remember what user paid to return same currency
;;
;; WORKFLOW:
;; 1. create-vault-with-strikes(start-block, expiry-timestamp, strikes-list) -> {vault-id, strike-ids}
;; 2. Backend converts user payment (BTC/STX -> sBTC)
;; 3. Backend calls place-bet(contract-id, quantity, payment-currency, payment-amount, sbtc-amount)
;; 4. After expiry (4 PM EST): close-vault -> settlement -> payouts
;; 5. Backend reads payment-currency from position, converts sBTC back

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-found (err u201))
(define-constant err-contract-expired (err u202))
(define-constant err-contract-inactive (err u203))
(define-constant err-insufficient-payment (err u204))
(define-constant err-invalid-parameters (err u205))
(define-constant err-already-settled (err u206))
(define-constant err-contract-paused (err u207))
(define-constant err-vault-not-found (err u208))
(define-constant err-vault-inactive (err u209))
(define-constant err-invalid-currency (err u210))
(define-constant err-already-claimed (err u211))

(define-constant protocol-fee-bps u2000)
(define-constant basis-points u10000)
(define-constant min-bet-amount u1000)

;; Data vars
(define-data-var contract-nonce uint u0)
(define-data-var vault-nonce uint u0)
(define-data-var is-paused bool false)
(define-data-var total-volume-sbtc uint u0)

;; Daily vault structure - one vault per day
(define-map daily-vaults
  { vault-id: uint }
  {
    start-block: uint,
    expiry-timestamp: uint,  ;; Unix timestamp (4 PM EST every day)
    total-prize-pool-sbtc: uint,
    total-call-volume-sbtc: uint,
    total-put-volume-sbtc: uint,
    total-stx-deposited: uint,
    is-active: bool,
    is-settled: bool,
    created-at: uint,
    settled-at: (optional uint)
  }
)

;; Option contracts (strikes)
(define-map option-contracts
  { contract-id: uint }
  {
    strike-price: uint,
    expiry-timestamp: uint,  ;; Unix timestamp (same as vault)
    option-type: (string-ascii 4),
    premium-sbtc: uint,
    reward-pool-sbtc: uint,
    total-volume-sbtc: uint,
    participant-count: uint,
    is-active: bool,
    is-settled: bool,
    created-at: uint,
    deposit-address: (optional (buff 33))
  }
)

;; Link contracts to vaults
(define-map contract-to-vault
  { contract-id: uint }
  { vault-id: uint }
)

;; User positions with payment currency tracking
(define-map user-positions
  { contract-id: uint, user: principal }
  {
    btc-address: (string-ascii 64),      ;; User's Bitcoin address for payouts
    position-size: uint,
    entry-premium-sbtc: uint,
    payment-currency: (string-ascii 4),  ;; "BTC" | "sBTC" | "STX"
    payment-amount: uint,                ;; Original amount in their currency
    sbtc-amount: uint,                   ;; Normalized sBTC amount
    created-at: uint,
    is-winner: (optional bool),
    payout-amount-sbtc: uint,
    is-claimed: bool
  }
)

;; Public functions

;; Create a daily vault (returns vault-id)
(define-public (create-daily-vault
    (start-block uint)
    (expiry-timestamp uint))
  (let ((vault-id (var-get vault-nonce)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> start-block u0) err-invalid-parameters)
    (asserts! (> expiry-timestamp u0) err-invalid-parameters)
    
    (map-set daily-vaults
      { vault-id: vault-id }
      {
        start-block: start-block,
        expiry-timestamp: expiry-timestamp,
        total-prize-pool-sbtc: u0,
        total-call-volume-sbtc: u0,
        total-put-volume-sbtc: u0,
        total-stx-deposited: u0,
        is-active: true,
        is-settled: false,
        created-at: stacks-block-height,
        settled-at: none
      })
    
    (var-set vault-nonce (+ vault-id u1))
    (ok vault-id)))

;; Create a strike for a vault (returns contract-id)
(define-public (create-strike
    (vault-id uint)
    (strike-price uint)
    (option-type (string-ascii 4))
    (premium uint))
  (let
    ((contract-id (var-get contract-nonce))
     (vault (unwrap! (map-get? daily-vaults { vault-id: vault-id }) err-vault-not-found)))
    
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (get is-active vault) err-vault-inactive)
    (asserts! (> strike-price u0) err-invalid-parameters)
    (asserts! (or (is-eq option-type "CALL") (is-eq option-type "PUT")) err-invalid-parameters)
    
    (map-set option-contracts
      { contract-id: contract-id }
      {
        strike-price: strike-price,
        expiry-timestamp: (get expiry-timestamp vault),
        option-type: option-type,
        premium-sbtc: premium,
        reward-pool-sbtc: u0,
        total-volume-sbtc: u0,
        participant-count: u0,
        is-active: true,
        is-settled: false,
        created-at: stacks-block-height,
        deposit-address: none
      })
    
    (map-set contract-to-vault
      { contract-id: contract-id }
      { vault-id: vault-id })
    
    (var-set contract-nonce (+ contract-id u1))
    (ok contract-id)))

;; ============================================
;; BATCH CREATION: Create vault + multiple strikes in ONE transaction
;; This is used for daily options with 5 CALLs + 5 PUTs (or more if BTC moves)
;; ============================================

;; Define strike data structure for batch input
;; Each strike has: price (e.g., 114000_00 = $114,000), type ("CALL" or "PUT"), premium (in sats)
(define-public (create-vault-with-strikes
    (start-block uint)           ;; Block height when vault starts
    (expiry-timestamp uint)           ;; Unix timestamp of expiry (4 PM EST)
    (strikes (list 20 {strike-price: uint, option-type: (string-ascii 4), premium: uint})))  ;; List of strikes to create
  (let
    (
      ;; Step 1: Get the vault ID for this new vault (before incrementing nonce)
      (vault-id (var-get vault-nonce))
      
      ;; Step 2: Get the starting contract ID for strikes (before creating any)
      (starting-contract-id (var-get contract-nonce))
    )
    ;; Validate: Only contract owner can create vaults
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    ;; Validate: start-block must be positive
    (asserts! (> start-block u0) err-invalid-parameters)
    
    ;; Validate: expiry-timestamp must be positive
    (asserts! (> expiry-timestamp u0) err-invalid-parameters)
    
    ;; Validate: strikes list must not be empty
    (asserts! (> (len strikes) u0) err-invalid-parameters)
    
    ;; Validate: strikes list must not exceed 20
    (asserts! (<= (len strikes) u20) err-invalid-parameters)
    
    ;; Step 3: Create the vault on Stacks blockchain
    (map-set daily-vaults
      { vault-id: vault-id }
      {
        start-block: start-block,
        expiry-timestamp: expiry-timestamp,
        total-prize-pool-sbtc: u0,           ;; Initially empty
        total-call-volume-sbtc: u0,          ;; No volume yet
        total-put-volume-sbtc: u0,           ;; No volume yet
        total-stx-deposited: u0,             ;; No deposits yet
        is-active: true,                     ;; Vault is active for betting
        is-settled: false,                   ;; Not settled yet
        created-at: stacks-block-height,     ;; Current block
        settled-at: none                     ;; No settlement yet
      }
    )
    
    ;; Step 4: Increment vault nonce for next vault
    (var-set vault-nonce (+ vault-id u1))
    
    ;; Step 5: Create all strikes using fold
    ;; fold iterates over the strikes list and creates each one
    ;; It accumulates the created contract IDs in a list
    (let
      (
        ;; fold parameters:
        ;; - strikes: list to iterate over
        ;; - initial state: {vault-id, next-contract-id, strike-ids: empty list}
        ;; - function: create-strike-fold (defined below)
        (result (fold create-strike-fold 
                      strikes 
                      {
                        vault-id: vault-id,
                        next-contract-id: starting-contract-id,
                        strike-ids: (list)
                      }))
      )
      
      ;; Step 6: Update contract nonce to reflect all strikes created
      ;; next-contract-id now points to the ID after the last strike
      (var-set contract-nonce (get next-contract-id result))
      
      ;; Step 7: Return both vault-id and list of created strike-ids
      (ok {
        vault-id: vault-id,
        strike-ids: (get strike-ids result)
      })
    )
  )
)

;; Helper function for fold - creates ONE strike and accumulates its ID
;; This is called once for each strike in the batch
(define-private (create-strike-fold
    ;; Input: one strike definition
    (strike {strike-price: uint, option-type: (string-ascii 4), premium: uint})
    ;; Accumulator state: tracks vault-id, next ID to use, and list of created IDs
    (state {vault-id: uint, next-contract-id: uint, strike-ids: (list 20 uint)}))
  (let
    (
      ;; Use the current contract ID for this strike
      (contract-id (get next-contract-id state))
      
      ;; Extract strike data from the input
      (strike-price (get strike-price strike))
      (option-type (get option-type strike))
      (premium (get premium strike))
      
      ;; Get vault data to copy expiry-timestamp to this strike
      (vault (unwrap-panic (map-get? daily-vaults { vault-id: (get vault-id state) })))
    )
    
    ;; Create the strike contract on Stacks
    (map-set option-contracts
      { contract-id: contract-id }
      {
        strike-price: strike-price,
        expiry-timestamp: (get expiry-timestamp vault),  ;; Copy from vault
        option-type: option-type,
        premium-sbtc: premium,
        reward-pool-sbtc: u0,              ;; No rewards yet
        total-volume-sbtc: u0,             ;; No volume yet
        participant-count: u0,             ;; No participants yet
        is-active: true,                   ;; Strike is active
        is-settled: false,                 ;; Not settled yet
        created-at: stacks-block-height,   ;; Current block
        deposit-address: none              ;; Backend will set this
      }
    )
    
    ;; Link this strike to the vault
    (map-set contract-to-vault
      { contract-id: contract-id }
      { vault-id: (get vault-id state) }
    )
    
    ;; Return updated state for next iteration:
    ;; - same vault-id
    ;; - increment contract ID for next strike
    ;; - append this contract-id to the list of created strikes
    {
      vault-id: (get vault-id state),
      next-contract-id: (+ contract-id u1),
      strike-ids: (unwrap-panic (as-max-len? (append (get strike-ids state) contract-id) u20))
    }
  )
)

;; Check if a vault exists (for duplicate prevention)
(define-read-only (vault-exists (vault-id uint))
  (is-some (map-get? daily-vaults { vault-id: vault-id }))
)

;; Check if a strike exists (for duplicate prevention)
(define-read-only (strike-exists (contract-id uint))
  (is-some (map-get? option-contracts { contract-id: contract-id }))
)

;; Place bet - Backend calls this after converting to sBTC
(define-public (place-bet
    (contract-id uint)
    (user-btc-address (string-ascii 64))  ;; User's Bitcoin address for settlement/payout
    (quantity uint)
    (payment-currency (string-ascii 4))
    (payment-amount uint)
    (sbtc-amount uint))
  (let
    (
      (contract (unwrap! (map-get? option-contracts { contract-id: contract-id }) err-not-found))
      (vault-link (unwrap! (map-get? contract-to-vault { contract-id: contract-id }) err-vault-not-found))
      (vault (unwrap! (map-get? daily-vaults { vault-id: (get vault-id vault-link) }) err-vault-not-found))
      (reward-contribution (/ (* sbtc-amount u8000) basis-points))
    )
    (asserts! (not (var-get is-paused)) err-contract-paused)
    (asserts! (get is-active contract) err-contract-inactive)
    (asserts! (get is-active vault) err-vault-inactive)
    ;; Note: Expiry check removed - backend validates before calling
    ;; (asserts! (> (get expiry-timestamp contract) current-time) err-contract-expired)
    (asserts! (> quantity u0) err-invalid-parameters)
    (asserts! (or (or (is-eq payment-currency "BTC") (is-eq payment-currency "sBTC")) (is-eq payment-currency "STX")) err-invalid-currency)
    
    ;; Transfer sBTC to contract (backend has already converted)
    ;; NOTE: Replace .sbtc-token with actual sBTC token contract when available
    ;; For now, using STX as placeholder
    (try! (stx-transfer? sbtc-amount tx-sender (as-contract tx-sender)))
    
    ;; Create or update position
    (match (map-get? user-positions { contract-id: contract-id, user: tx-sender })
      existing-position
        (map-set user-positions
          { contract-id: contract-id, user: tx-sender }
          (merge existing-position {
            position-size: (+ (get position-size existing-position) quantity),
            sbtc-amount: (+ (get sbtc-amount existing-position) sbtc-amount)
          })
        )
      (map-set user-positions
        { contract-id: contract-id, user: tx-sender }
        {
          btc-address: user-btc-address,  ;; Store user's Bitcoin address
          position-size: quantity,
          entry-premium-sbtc: (get premium-sbtc contract),
          payment-currency: payment-currency,
          payment-amount: payment-amount,
          sbtc-amount: sbtc-amount,
          created-at: stacks-block-height,
          is-winner: none,
          payout-amount-sbtc: u0,
          is-claimed: false
        }
      )
    )
    
    ;; Update contract stats
    (map-set option-contracts
      { contract-id: contract-id }
      (merge contract {
        reward-pool-sbtc: (+ (get reward-pool-sbtc contract) reward-contribution),
        total-volume-sbtc: (+ (get total-volume-sbtc contract) sbtc-amount),
        participant-count: (+ (get participant-count contract) u1)
      })
    )
    
    ;; Update vault stats
    (map-set daily-vaults
      { vault-id: (get vault-id vault-link) }
      (merge vault {
        total-prize-pool-sbtc: (+ (get total-prize-pool-sbtc vault) reward-contribution),
        total-call-volume-sbtc: (if (is-eq (get option-type contract) "CALL")
                                  (+ (get total-call-volume-sbtc vault) sbtc-amount)
                                  (get total-call-volume-sbtc vault)),
        total-put-volume-sbtc: (if (is-eq (get option-type contract) "PUT")
                                 (+ (get total-put-volume-sbtc vault) sbtc-amount)
                                 (get total-put-volume-sbtc vault)),
        total-stx-deposited: (if (is-eq payment-currency "STX")
                               (+ (get total-stx-deposited vault) payment-amount)
                               (get total-stx-deposited vault))
      })
    )
    
    (var-set total-volume-sbtc (+ (var-get total-volume-sbtc) sbtc-amount))
    (ok sbtc-amount)
  )
)

;; Claim payout - Returns sBTC to backend for conversion
(define-public (claim-payout (contract-id uint) (user principal))
  (let
    (
      (position (unwrap! (map-get? user-positions { contract-id: contract-id, user: user }) err-not-found))
      (payout-sbtc (get payout-amount-sbtc position))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)  ;; Only backend can call
    (asserts! (is-some (get is-winner position)) err-not-found)
    (asserts! (unwrap-panic (get is-winner position)) err-not-found)
    (asserts! (not (get is-claimed position)) err-already-claimed)
    (asserts! (> payout-sbtc u0) err-invalid-parameters)
    
    ;; Transfer sBTC to backend (backend will convert back to user's currency)
    ;; NOTE: Replace with .sbtc-token when available
    (try! (as-contract (stx-transfer? payout-sbtc tx-sender contract-owner)))
    
    ;; Mark as claimed
    (map-set user-positions
      { contract-id: contract-id, user: user }
      (merge position { is-claimed: true }))
    
    (ok payout-sbtc)
  )
)

;; Read-only functions
(define-read-only (get-vault (vault-id uint))
  (ok (map-get? daily-vaults { vault-id: vault-id }))
)

(define-read-only (get-contract (contract-id uint))
  (ok (map-get? option-contracts { contract-id: contract-id }))
)

(define-read-only (get-contract-vault (contract-id uint))
  (ok (map-get? contract-to-vault { contract-id: contract-id }))
)

(define-read-only (get-position (contract-id uint) (user principal))
  (ok (map-get? user-positions { contract-id: contract-id, user: user }))
)

(define-read-only (get-vault-count)
  (ok (var-get vault-nonce))
)

(define-read-only (get-contract-count)
  (ok (var-get contract-nonce))
)

(define-read-only (get-total-volume)
  (ok (var-get total-volume-sbtc))
)

(define-read-only (is-vault-active (vault-id uint))
  (match (map-get? daily-vaults { vault-id: vault-id })
    vault (ok (and (get is-active vault) (not (get is-settled vault))))
    (ok false)
  )
)

;; Get payment info for payout conversion
(define-read-only (get-payout-info (contract-id uint) (user principal))
  (match (map-get? user-positions { contract-id: contract-id, user: user })
    position (ok {
      btc-address: (get btc-address position),
      payout-sbtc: (get payout-amount-sbtc position),
      payment-currency: (get payment-currency position),
      payment-amount: (get payment-amount position),
      is-winner: (get is-winner position),
      is-claimed: (get is-claimed position)
    })
    err-not-found
  )
)

;; Admin functions
(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set is-paused true)
    (ok true)
  )
)

(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set is-paused false)
    (ok true)
  )
)

(define-public (close-vault (vault-id uint))
  (let
    (
      (vault (unwrap! (map-get? daily-vaults { vault-id: vault-id }) err-vault-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    ;; Note: Expiry check removed - backend validates timing
    
    (map-set daily-vaults
      { vault-id: vault-id }
      (merge vault { is-active: false })
    )
    
    (ok true)
  )
)

(define-public (mark-vault-settled (vault-id uint))
  (let
    (
      (vault (unwrap! (map-get? daily-vaults { vault-id: vault-id }) err-vault-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (get is-settled vault)) err-already-settled)
    
    (map-set daily-vaults
      { vault-id: vault-id }
      (merge vault { 
        is-settled: true,
        is-active: false,
        settled-at: (some stacks-block-height)
      })
    )
    
    (ok true)
  )
)

;; Update position after settlement (called by settlement contract)
(define-public (update-position-settlement
    (contract-id uint)
    (user principal)
    (is-winner-flag bool)
    (payout-sbtc uint))
  (let
    (
      (position (unwrap! (map-get? user-positions { contract-id: contract-id, user: user }) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    (map-set user-positions
      { contract-id: contract-id, user: user }
      (merge position {
        is-winner: (some is-winner-flag),
        payout-amount-sbtc: payout-sbtc
      })
    )
    
    (ok true)
  )
)

(define-public (deactivate-contract (contract-id uint))
  (let
    (
      (contract (unwrap! (map-get? option-contracts { contract-id: contract-id }) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    (map-set option-contracts
      { contract-id: contract-id }
      (merge contract { is-active: false })
    )
    
    (ok true)
  )
)


```
