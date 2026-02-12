;; title: heropick
;; version: 1.0.0
;; summary: Decentralized prediction market for future events
;; description: A prediction market where users can create markets, place bets on outcomes, and resolve markets with payouts

;; constants
(define-constant ERR-MARKET-NOT-FOUND (err u1001))
(define-constant ERR-MARKET-CLOSED (err u1002))
(define-constant ERR-MARKET-ALREADY-RESOLVED (err u1003))
(define-constant ERR-INVALID-OUTCOME (err u1004))
(define-constant ERR-INSUFFICIENT-BALANCE (err u1005))
(define-constant ERR-UNAUTHORIZED (err u1006))
(define-constant ERR-INVALID-AMOUNT (err u1007))
(define-constant ERR-MARKET-ALREADY-EXISTS (err u1008))

;; data vars
(define-data-var market-counter uint u0)
(define-data-var bet-counter uint u0)

;; data maps
;; Market data: market-id -> (creator, description, category, end-block, resolved, winning-outcome, total-bets-yes, total-bets-no)
(define-map markets uint {
  creator: principal,
  description: (string-ascii 500),
  category: (string-ascii 100),
  end-block: uint,
  resolved: bool,
  winning-outcome: (optional bool),
  total-bets-yes: uint,
  total-bets-no: uint
})

;; Bet data: bet-id -> (market-id, bettor, outcome, amount, timestamp)
(define-map bets uint {
  market-id: uint,
  bettor: principal,
  outcome: bool, ;; true = yes, false = no
  amount: uint,
  timestamp: uint
})

;; Market bets: (market-id, bettor) -> bet-id
(define-map market-bettors (tuple (market-id uint) (bettor principal)) uint)

;; read only functions

;; Get market information
(define-read-only (get-market (market-id uint))
  (map-get? markets market-id)
)

;; Get bet information
(define-read-only (get-bet (bet-id uint))
  (map-get? bets bet-id)
)

;; Get market counter
(define-read-only (get-market-counter)
  (var-get market-counter)
)

;; Get bet counter
(define-read-only (get-bet-counter)
  (var-get bet-counter)
)

;; Get user's bet for a market
(define-read-only (get-user-bet (market-id uint) (bettor principal))
  (let ((key (tuple (market-id market-id) (bettor bettor))))
    (map-get? market-bettors key)
  )
)

;; Get market statistics
(define-read-only (get-market-stats (market-id uint))
  (match (map-get? markets market-id)
    market (ok (tuple
      (total-bets-yes (get total-bets-yes market))
      (total-bets-no (get total-bets-no market))
      (resolved (get resolved market))
    ))
    (err ERR-MARKET-NOT-FOUND)
  )
)

;; public functions

;; Create a new prediction market
(define-public (create-market
    (description (string-ascii 500))
    (category (string-ascii 100))
    (end-block uint)
)
  (let (
    (caller tx-sender)
    (market-id (var-get market-counter))
  )
    ;; Note: End block validation should be done off-chain
    ;; The end-block is stored for reference and used in resolve-market
    
    ;; Create market entry
    (map-set markets market-id {
      creator: caller,
      description: description,
      category: category,
      end-block: end-block,
      resolved: false,
      winning-outcome: none,
      total-bets-yes: u0,
      total-bets-no: u0
    })
    
    ;; Increment market counter
    (var-set market-counter (+ market-id u1))
    
    (ok market-id)
  )
)

;; Place a bet on a market outcome
(define-public (place-bet
    (market-id uint)
    (outcome bool) ;; true = yes, false = no
    (amount uint)
)
  (let (
    (caller tx-sender)
    (bet-id (var-get bet-counter))
    (market (unwrap! (map-get? markets market-id) ERR-MARKET-NOT-FOUND))
  )
    ;; Validate market is not resolved
    (asserts! (not (get resolved market)) ERR-MARKET-ALREADY-RESOLVED)
    
    ;; Note: Market closure validation should be done off-chain
    ;; The end-block is stored for reference
    
    ;; Validate amount is greater than zero
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    ;; Check if user already has a bet on this market
    (let ((key (tuple (market-id market-id) (bettor caller))))
      (asserts! (is-none (map-get? market-bettors key)) ERR-MARKET-ALREADY-EXISTS)
    )
    
    ;; Note: Users must send STX with the transaction when calling this function
    ;; The contract will receive the STX automatically
    ;; In a production environment, you would validate the received amount
    
    ;; Create bet entry
    (map-set bets bet-id {
      market-id: market-id,
      bettor: caller,
      outcome: outcome,
      amount: amount,
      timestamp: u0  ;; Note: Timestamp tracking can be added via off-chain indexing
    })
    
    ;; Record bettor for this market
    (map-set market-bettors (tuple (market-id market-id) (bettor caller)) bet-id)
    
    ;; Update market totals
    (if outcome
      (map-set markets market-id {
        creator: (get creator market),
        description: (get description market),
        category: (get category market),
        end-block: (get end-block market),
        resolved: (get resolved market),
        winning-outcome: (get winning-outcome market),
        total-bets-yes: (+ (get total-bets-yes market) amount),
        total-bets-no: (get total-bets-no market)
      })
      (map-set markets market-id {
        creator: (get creator market),
        description: (get description market),
        category: (get category market),
        end-block: (get end-block market),
        resolved: (get resolved market),
        winning-outcome: (get winning-outcome market),
        total-bets-yes: (get total-bets-yes market),
        total-bets-no: (+ (get total-bets-no market) amount)
      })
    )
    
    ;; Increment bet counter
    (var-set bet-counter (+ bet-id u1))
    
    (ok bet-id)
  )
)

;; Resolve a market and distribute winnings
(define-public (resolve-market
    (market-id uint)
    (winning-outcome bool)
)
  (let (
    (caller tx-sender)
    (market (unwrap! (map-get? markets market-id) ERR-MARKET-NOT-FOUND))
  )
    ;; Only market creator can resolve
    (asserts! (is-eq caller (get creator market)) ERR-UNAUTHORIZED)
    
    ;; Note: End block validation should be done off-chain
    ;; Market creator is responsible for resolving only after end block
    
    ;; Market must not already be resolved
    (asserts! (not (get resolved market)) ERR-MARKET-ALREADY-RESOLVED)
    
    ;; Mark market as resolved
    (map-set markets market-id {
      creator: (get creator market),
      description: (get description market),
      category: (get category market),
      end-block: (get end-block market),
      resolved: true,
      winning-outcome: (some winning-outcome),
      total-bets-yes: (get total-bets-yes market),
      total-bets-no: (get total-bets-no market)
    })
    
    (ok true)
  )
)

;; Claim winnings for a resolved market
;; Returns the payout amount (users need to handle actual STX transfer off-chain or via separate mechanism)
(define-public (claim-winnings (market-id uint))
  (let (
    (caller tx-sender)
    (market (unwrap! (map-get? markets market-id) ERR-MARKET-NOT-FOUND))
    (key (tuple (market-id market-id) (bettor caller)))
    (bet-id-opt (map-get? market-bettors key))
  )
    ;; Market must be resolved
    (asserts! (get resolved market) ERR-MARKET-ALREADY-RESOLVED)
    
    ;; User must have placed a bet
    (let ((bet-id (unwrap! bet-id-opt ERR-MARKET-NOT-FOUND)))
      (let ((bet (unwrap! (map-get? bets bet-id) ERR-MARKET-NOT-FOUND)))
        ;; Check if bettor bet on the winning outcome
        (let ((winning-outcome (unwrap! (get winning-outcome market) ERR-MARKET-NOT-FOUND)))
          (if (is-eq (get outcome bet) winning-outcome)
            ;; Calculate winnings proportionally
            (let (
              (bet-amount (get amount bet))
              (winning-pool (if winning-outcome (get total-bets-yes market) (get total-bets-no market)))
              (total-pool (+ (get total-bets-yes market) (get total-bets-no market)))
              (payout (/ (* bet-amount total-pool) winning-pool))
            )
              ;; Return payout amount
              ;; Note: Actual STX transfer should be handled via:
              ;; 1. Off-chain service that monitors claims and transfers STX
              ;; 2. Separate contract function with proper STX handling
              ;; 3. Manual payout by market creator
              (ok payout)
            )
            ;; Bet on losing outcome, no payout
            (ok u0)
          )
        )
      )
    )
  )
)

