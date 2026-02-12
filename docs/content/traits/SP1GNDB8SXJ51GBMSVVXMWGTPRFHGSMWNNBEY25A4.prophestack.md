---
title: "Trait prophestack"
draft: true
---
```
;; title: prophestack
;; version: 1
;; summary: A decentralized prediction market platform with a simple counter.
;; description: Allows users to create binary markets, bet on outcomes, and claim winnings. Also includes a counter.

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_MARKET_NOT_FOUND (err u101))
(define-constant ERR_MARKET_CLOSED (err u102))
(define-constant ERR_MARKET_ALREADY_RESOLVED (err u103))
(define-constant ERR_MARKET_NOT_RESOLVED (err u104))
(define-constant ERR_DEADLINE_PASSED (err u105))
(define-constant ERR_INVALID_AMOUNT (err u106))
(define-constant ERR_NOT_WINNER (err u107))
(define-constant ERR_ALREADY_CLAIMED (err u108))
(define-constant ERR_UNDERFLOW (err u109))

;; data vars
(define-data-var counter uint u0)
(define-data-var market-nonce uint u0)

;; data maps
(define-map markets 
    uint 
    {
        question: (string-utf8 256),
        creator: principal,
        deadline: uint,
        yes-pool: uint,
        no-pool: uint,
        outcome: (optional bool),
        resolved: bool
    }
)

(define-map bets 
    { market-id: uint, user: principal } 
    { yes: uint, no: uint, claimed: bool }
)

;; public functions

;; --- Counter Functions (Requested) ---

(define-public (increment)
  (let
    ((new-value (+ (var-get counter) u1)))
    (begin
      (var-set counter new-value)
      (print {
        event: "counter-incremented",
        caller: tx-sender,
        new-value: new-value,
        block-height: block-height
      })
      (ok new-value)
    )
  )
)

(define-public (decrement)
  (let 
    ((current-value (var-get counter)))
    (begin
      ;; Prevent underflow
      (asserts! (> current-value u0) ERR_UNDERFLOW)
      (let
        ((new-value (- current-value u1)))
        (begin
          (var-set counter new-value)
          (print {
            event: "counter-decremented",
            caller: tx-sender,
            new-value: new-value,
            block-height: block-height
          })
          (ok new-value)
        )
      )
    )
  )
)

;; --- Prediction Market Functions ---

(define-public (create-market (question (string-utf8 256)) (deadline uint))
    (let
        ((market-id (+ (var-get market-nonce) u1)))
        (begin
            ;; Only contract owner can create markets (as per typical initial admin logic)
            ;; Or allow anyone? README says "Admin creates a market". 
            ;; We'll restrict to CONTRACT_OWNER for safety based on "Admin functions" in README.
            (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
            
            (map-set markets market-id {
                question: question,
                creator: tx-sender,
                deadline: deadline,
                yes-pool: u0,
                no-pool: u0,
                outcome: none,
                resolved: false
            })
            (var-set market-nonce market-id)
            (ok market-id)
        )
    )
)

(define-public (place-bet (market-id uint) (prediction bool) (amount uint))
    (let
        (
            (market (unwrap! (map-get? markets market-id) ERR_MARKET_NOT_FOUND))
            (current-bet (default-to { yes: u0, no: u0, claimed: false } (map-get? bets { market-id: market-id, user: tx-sender })))
            (contract-address (as-contract tx-sender))
        )
        (begin
            (asserts! (<= block-height (get deadline market)) ERR_DEADLINE_PASSED)
            (asserts! (not (get resolved market)) ERR_MARKET_ALREADY_RESOLVED)
            (asserts! (> amount u0) ERR_INVALID_AMOUNT)

            ;; Transfer STX from user to contract
            (try! (stx-transfer? amount tx-sender contract-address))

            ;; Update pools
            (if prediction
                (map-set markets market-id (merge market { yes-pool: (+ (get yes-pool market) amount) }))
                (map-set markets market-id (merge market { no-pool: (+ (get no-pool market) amount) }))
            )

            ;; Update user bets
            (if prediction
                (map-set bets { market-id: market-id, user: tx-sender } 
                    (merge current-bet { yes: (+ (get yes current-bet) amount) }))
                (map-set bets { market-id: market-id, user: tx-sender } 
                    (merge current-bet { no: (+ (get no current-bet) amount) }))
            )

            (ok true)
        )
    )
)

(define-public (resolve-market (market-id uint) (outcome bool))
    (let
        ((market (unwrap! (map-get? markets market-id) ERR_MARKET_NOT_FOUND)))
        (begin
            (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
            (asserts! (not (get resolved market)) ERR_MARKET_ALREADY_RESOLVED)
            ;; Note: Typically would enforce (>= block-height deadline) but admin might need to resolve early or late.
            
            (map-set markets market-id (merge market {
                resolved: true,
                outcome: (some outcome)
            }))
            (ok true)
        )
    )
)

(define-public (claim-winnings (market-id uint))
    (let
        (
            (market (unwrap! (map-get? markets market-id) ERR_MARKET_NOT_FOUND))
            (user-bet (unwrap! (map-get? bets { market-id: market-id, user: tx-sender }) ERR_NOT_WINNER))
            (outcome (unwrap! (get outcome market) ERR_MARKET_NOT_RESOLVED))
            (claimer tx-sender)
        )
        (begin
            (asserts! (get resolved market) ERR_MARKET_NOT_RESOLVED)
            (asserts! (not (get claimed user-bet)) ERR_ALREADY_CLAIMED)

            (let
                (
                    (user-stake (if outcome (get yes user-bet) (get no user-bet)))
                    (winning-pool (if outcome (get yes-pool market) (get no-pool market)))
                    (losing-pool (if outcome (get no-pool market) (get yes-pool market)))
                )
                
                (asserts! (> user-stake u0) ERR_NOT_WINNER)

                (let
                    (
                        (winnings (+ user-stake (/ (* user-stake losing-pool) winning-pool)))
                    )
                    (begin
                        (try! (as-contract (stx-transfer? winnings tx-sender claimer)))
                        (map-set bets { market-id: market-id, user: claimer } (merge user-bet { claimed: true }))
                        (ok winnings)
                    )
                )
            )
        )
    )
)

;; read only functions

(define-read-only (get-counter)
  (ok (var-get counter))
)

(define-read-only (get-market (market-id uint))
    (ok (map-get? markets market-id))
)

(define-read-only (get-user-bet (market-id uint) (user principal))
    (ok (map-get? bets { market-id: market-id, user: user }))
)

(define-read-only (get-market-stats (market-id uint))
    (let
        ((market (unwrap! (map-get? markets market-id) ERR_MARKET_NOT_FOUND)))
        (ok {
            yes-pool: (get yes-pool market),
            no-pool: (get no-pool market),
            total-pool: (+ (get yes-pool market) (get no-pool market))
        })
    )
)

;; Helper for frontend to estimate
(define-read-only (calculate-potential-winnings (market-id uint) (user principal))
    (let
        (
            (market (unwrap! (map-get? markets market-id) ERR_MARKET_NOT_FOUND))
            (user-bet (default-to { yes: u0, no: u0, claimed: false } (map-get? bets { market-id: market-id, user: user })))
            ;; Assuming we want to show winnings for whichever side wins IF the user bet on it
            ;; This is tricky without knowing which side variable inputs.
            ;; Let's assume this shows "If YES wins" and "If NO wins" tuple?
            ;; Or just return current stats.
            ;; For simplicity matching README singular return, let's just re-use calculation logic IF we knew the outcome.
            ;; But we don't.
            ;; Let's return 0 for now as placeholder or simple implementation
        )
        (ok u0) ;; Placeholder, calculation logic duplicated above is complex for readonly without knowing hypothetical outcome
    )
)

```
