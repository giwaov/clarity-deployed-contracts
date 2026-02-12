;; StacksBet Arena - Decentralized Prediction Markets on Stacks
;; A prediction market protocol with binary betting and oracle resolution

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u2001))
(define-constant ERR-MARKET-NOT-FOUND (err u2002))
(define-constant ERR-MARKET-CLOSED (err u2003))
(define-constant ERR-MARKET-NOT-RESOLVED (err u2004))
(define-constant ERR-ALREADY-RESOLVED (err u2005))
(define-constant ERR-INVALID-AMOUNT (err u2006))
(define-constant ERR-INVALID-OUTCOME (err u2007))
(define-constant ERR-NO-POSITION (err u2008))
(define-constant ERR-ALREADY-CLAIMED (err u2009))
(define-constant ERR-MARKET-ACTIVE (err u2010))
(define-constant ERR-INSUFFICIENT-LIQUIDITY (err u2011))

;; Outcome constants
(define-constant OUTCOME-YES u1)
(define-constant OUTCOME-NO u2)
(define-constant OUTCOME-INVALID u3)

;; Fee constants (basis points)
(define-constant PLATFORM-FEE u200)        ;; 2% platform fee
(define-constant CREATOR-FEE u50)          ;; 0.5% to market creator
(define-constant LIQUIDITY-FEE u50)        ;; 0.5% to LPs

;; Data Variables
(define-data-var next-market-id uint u1)
(define-data-var total-volume uint u0)
(define-data-var total-markets uint u0)
(define-data-var total-bets uint u0)
(define-data-var treasury principal CONTRACT-OWNER)
(define-data-var protocol-paused bool false)

;; Data Maps
(define-map markets
  { market-id: uint }
  {
    creator: principal,
    title: (string-utf8 200),
    description: (string-utf8 500),
    category: (string-ascii 50),
    resolution-source: (string-utf8 200),
    end-time: uint,
    resolution-time: uint,
    total-yes-amount: uint,
    total-no-amount: uint,
    resolved: bool,
    outcome: uint,
    created-at: uint,
    is-active: bool
  }
)

(define-map positions
  { market-id: uint, user: principal }
  {
    yes-shares: uint,
    no-shares: uint,
    total-invested: uint,
    claimed: bool
  }
)

(define-map user-stats
  { user: principal }
  {
    total-bets: uint,
    total-volume: uint,
    total-winnings: uint,
    total-losses: uint,
    markets-created: uint,
    win-rate: uint
  }
)

(define-map oracles
  { oracle: principal }
  { is-active: bool }
)

(define-map leaderboard
  { rank: uint }
  { user: principal, score: uint }
)

;; Read-only functions
(define-read-only (get-market (market-id uint))
  (map-get? markets { market-id: market-id })
)

(define-read-only (get-position (market-id uint) (user principal))
  (default-to
    { yes-shares: u0, no-shares: u0, total-invested: u0, claimed: false }
    (map-get? positions { market-id: market-id, user: user })
  )
)

(define-read-only (get-user-stats (user principal))
  (default-to
    {
      total-bets: u0,
      total-volume: u0,
      total-winnings: u0,
      total-losses: u0,
      markets-created: u0,
      win-rate: u0
    }
    (map-get? user-stats { user: user })
  )
)

(define-read-only (get-total-volume)
  (var-get total-volume)
)

(define-read-only (get-total-markets)
  (var-get total-markets)
)

(define-read-only (get-total-bets)
  (var-get total-bets)
)

(define-read-only (get-next-market-id)
  (var-get next-market-id)
)

(define-read-only (is-oracle (oracle principal))
  (default-to
    { is-active: false }
    (map-get? oracles { oracle: oracle })
  )
)

(define-read-only (get-odds (market-id uint))
  (let (
    (market (unwrap! (get-market market-id) { yes-odds: u0, no-odds: u0 }))
    (total-yes (get total-yes-amount market))
    (total-no (get total-no-amount market))
    (total (+ total-yes total-no))
  )
    (if (is-eq total u0)
      { yes-odds: u5000, no-odds: u5000 }
      {
        yes-odds: (/ (* total-no u10000) total),
        no-odds: (/ (* total-yes u10000) total)
      }
    )
  )
)

(define-read-only (calculate-payout (market-id uint) (user principal))
  (let (
    (market (unwrap! (get-market market-id) u0))
    (position (get-position market-id user))
    (outcome (get outcome market))
  )
    (if (not (get resolved market))
      u0
      (if (is-eq outcome OUTCOME-YES)
        (let (
          (total-pool (+ (get total-yes-amount market) (get total-no-amount market)))
          (total-yes (get total-yes-amount market))
          (user-shares (get yes-shares position))
        )
          (if (is-eq total-yes u0)
            u0
            (/ (* user-shares total-pool) total-yes)
          )
        )
        (if (is-eq outcome OUTCOME-NO)
          (let (
            (total-pool (+ (get total-yes-amount market) (get total-no-amount market)))
            (total-no (get total-no-amount market))
            (user-shares (get no-shares position))
          )
            (if (is-eq total-no u0)
              u0
              (/ (* user-shares total-pool) total-no)
            )
          )
          ;; Invalid outcome - refund
          (get total-invested position)
        )
      )
    )
  )
)

;; Public functions

;; Create a new prediction market
(define-public (create-market 
  (title (string-utf8 200))
  (description (string-utf8 500))
  (category (string-ascii 50))
  (resolution-source (string-utf8 200))
  (end-time uint)
  (resolution-time uint)
  (initial-liquidity uint)
)
  (let (
    (market-id (var-get next-market-id))
    (user-data (get-user-stats tx-sender))
  )
    (asserts! (not (var-get protocol-paused)) ERR-MARKET-CLOSED)
    (asserts! (> end-time block-height) ERR-INVALID-AMOUNT)
    (asserts! (> resolution-time end-time) ERR-INVALID-AMOUNT)
    (asserts! (>= initial-liquidity u1000000) ERR-INVALID-AMOUNT) ;; Min 1 STX
    
    ;; Transfer initial liquidity
    (try! (stx-transfer? initial-liquidity tx-sender (as-contract tx-sender)))
    
    ;; Create market
    (map-set markets
      { market-id: market-id }
      {
        creator: tx-sender,
        title: title,
        description: description,
        category: category,
        resolution-source: resolution-source,
        end-time: end-time,
        resolution-time: resolution-time,
        total-yes-amount: (/ initial-liquidity u2),
        total-no-amount: (/ initial-liquidity u2),
        resolved: false,
        outcome: u0,
        created-at: block-height,
        is-active: true
      }
    )
    
    ;; Update creator stats
    (map-set user-stats
      { user: tx-sender }
      (merge user-data { markets-created: (+ (get markets-created user-data) u1) })
    )
    
    ;; Update protocol stats
    (var-set next-market-id (+ market-id u1))
    (var-set total-markets (+ (var-get total-markets) u1))
    (var-set total-volume (+ (var-get total-volume) initial-liquidity))
    
    (ok market-id)
  )
)

;; Place a bet on a market
(define-public (place-bet (market-id uint) (outcome uint) (amount uint))
  (let (
    (market (unwrap! (get-market market-id) ERR-MARKET-NOT-FOUND))
    (position (get-position market-id tx-sender))
    (user-data (get-user-stats tx-sender))
  )
    (asserts! (not (var-get protocol-paused)) ERR-MARKET-CLOSED)
    (asserts! (get is-active market) ERR-MARKET-CLOSED)
    (asserts! (< block-height (get end-time market)) ERR-MARKET-CLOSED)
    (asserts! (or (is-eq outcome OUTCOME-YES) (is-eq outcome OUTCOME-NO)) ERR-INVALID-OUTCOME)
    (asserts! (>= amount u100000) ERR-INVALID-AMOUNT) ;; Min 0.1 STX
    
    (let (
      (platform-cut (/ (* amount PLATFORM-FEE) u10000))
      (creator-cut (/ (* amount CREATOR-FEE) u10000))
      (net-amount (- amount (+ platform-cut creator-cut)))
    )
      ;; Transfer STX
      (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      
      ;; Pay creator fee
      (try! (as-contract (stx-transfer? creator-cut tx-sender (get creator market))))
      
      ;; Update market totals
      (if (is-eq outcome OUTCOME-YES)
        (map-set markets
          { market-id: market-id }
          (merge market { total-yes-amount: (+ (get total-yes-amount market) net-amount) })
        )
        (map-set markets
          { market-id: market-id }
          (merge market { total-no-amount: (+ (get total-no-amount market) net-amount) })
        )
      )
      
      ;; Update user position
      (map-set positions
        { market-id: market-id, user: tx-sender }
        {
          yes-shares: (if (is-eq outcome OUTCOME-YES)
            (+ (get yes-shares position) net-amount)
            (get yes-shares position)
          ),
          no-shares: (if (is-eq outcome OUTCOME-NO)
            (+ (get no-shares position) net-amount)
            (get no-shares position)
          ),
          total-invested: (+ (get total-invested position) amount),
          claimed: false
        }
      )
      
      ;; Update user stats
      (map-set user-stats
        { user: tx-sender }
        (merge user-data {
          total-bets: (+ (get total-bets user-data) u1),
          total-volume: (+ (get total-volume user-data) amount)
        })
      )
      
      ;; Update protocol stats
      (var-set total-bets (+ (var-get total-bets) u1))
      (var-set total-volume (+ (var-get total-volume) amount))
      
      (ok { shares: net-amount, fee: (+ platform-cut creator-cut) })
    )
  )
)

;; Resolve a market (oracle only)
(define-public (resolve-market (market-id uint) (outcome uint))
  (let (
    (market (unwrap! (get-market market-id) ERR-MARKET-NOT-FOUND))
    (oracle-data (is-oracle tx-sender))
  )
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (get is-active oracle-data)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get resolved market)) ERR-ALREADY-RESOLVED)
    (asserts! (>= block-height (get resolution-time market)) ERR-MARKET-ACTIVE)
    (asserts! (or (is-eq outcome OUTCOME-YES) 
                  (or (is-eq outcome OUTCOME-NO) 
                      (is-eq outcome OUTCOME-INVALID))) ERR-INVALID-OUTCOME)
    
    (map-set markets
      { market-id: market-id }
      (merge market { 
        resolved: true, 
        outcome: outcome,
        is-active: false 
      })
    )
    
    (ok true)
  )
)

;; Claim winnings
(define-public (claim-winnings (market-id uint))
  (let (
    (market (unwrap! (get-market market-id) ERR-MARKET-NOT-FOUND))
    (position (get-position market-id tx-sender))
    (user-data (get-user-stats tx-sender))
    (payout (calculate-payout market-id tx-sender))
    (claimant tx-sender)
  )
    (asserts! (get resolved market) ERR-MARKET-NOT-RESOLVED)
    (asserts! (not (get claimed position)) ERR-ALREADY-CLAIMED)
    (asserts! (> payout u0) ERR-NO-POSITION)
    
    ;; Transfer winnings (from contract principal to claimant)
    (try! (as-contract (stx-transfer? payout tx-sender claimant)))
    
    ;; Mark as claimed
    (map-set positions
      { market-id: market-id, user: tx-sender }
      (merge position { claimed: true })
    )
    
    ;; Update user stats
    (let (
      (invested (get total-invested position))
      (profit (if (> payout invested) (- payout invested) u0))
      (loss (if (< payout invested) (- invested payout) u0))
      (old-wins (get total-winnings user-data))
      (old-losses (get total-losses user-data))
      (old-bets (get total-bets user-data))
      (new-wins (+ old-wins profit))
      (new-losses (+ old-losses loss))
      (win-rate (if (> old-bets u0) 
        (/ (* (if (> profit u0) (+ old-bets u1) old-bets) u100) (+ old-bets u1))
        u0
      ))
    )
      (map-set user-stats
        { user: tx-sender }
        (merge user-data {
          total-winnings: new-wins,
          total-losses: new-losses,
          win-rate: win-rate
        })
      )
    )
    
    (ok payout)
  )
)

;; Cancel market (creator only, before any bets)
(define-public (cancel-market (market-id uint))
  (let (
    (market (unwrap! (get-market market-id) ERR-MARKET-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get creator market)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get resolved market)) ERR-ALREADY-RESOLVED)
    
    ;; Set as invalid to allow refunds
    (map-set markets
      { market-id: market-id }
      (merge market { 
        resolved: true, 
        outcome: OUTCOME-INVALID,
        is-active: false 
      })
    )
    
    (ok true)
  )
)

;; Admin functions

;; Add oracle
(define-public (add-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set oracles { oracle: oracle } { is-active: true })
    (ok true)
  )
)

;; Remove oracle
(define-public (remove-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set oracles { oracle: oracle } { is-active: false })
    (ok true)
  )
)

;; Toggle protocol pause
(define-public (toggle-protocol)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set protocol-paused (not (var-get protocol-paused)))
    (ok true)
  )
)

;; Update treasury
(define-public (set-treasury (new-treasury principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set treasury new-treasury)
    (ok true)
  )
)

;; Emergency close market
(define-public (emergency-close (market-id uint))
  (let (
    (market (unwrap! (get-market market-id) ERR-MARKET-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    (map-set markets
      { market-id: market-id }
      (merge market { 
        resolved: true, 
        outcome: OUTCOME-INVALID,
        is-active: false 
      })
    )
    
    (ok true)
  )
)
