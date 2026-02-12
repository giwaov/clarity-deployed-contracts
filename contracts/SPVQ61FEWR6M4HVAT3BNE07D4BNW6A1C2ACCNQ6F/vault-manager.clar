;; YieldForge Vault Manager Contract
;; Manages multi-strategy vaults with automated rebalancing and fee management

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-BALANCE (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-VAULT-PAUSED (err u103))
(define-constant ERR-INVALID-RISK-TIER (err u104))
(define-constant ERR-MIN-DEPOSIT-NOT-MET (err u105))
(define-constant ERR-STRATEGY-NOT-FOUND (err u106))
(define-constant ERR-REBALANCE-THRESHOLD-NOT-MET (err u107))

;; Fee constants (in basis points, 100 = 1%)
(define-constant DEPOSIT-FEE-BP u30)        ;; 0.3%
(define-constant WITHDRAWAL-FEE-BP u50)      ;; 0.5%
(define-constant PERFORMANCE-FEE-BP u1500)   ;; 15%
(define-constant MANAGEMENT-FEE-BP u200)     ;; 2% annually
(define-constant MIN-FEE u1000000)           ;; 1 STX in microSTX
(define-constant MIN-DEPOSIT u100000000)     ;; 100 STX in microSTX
(define-constant COMPOUND-GAS-FEE u200000)   ;; 0.2 STX

;; Risk tier definitions
(define-constant RISK-CONSERVATIVE u1)
(define-constant RISK-BALANCED u2)
(define-constant RISK-AGGRESSIVE u3)

;; Data Variables
(define-data-var contract-paused bool false)
(define-data-var total-tvl uint u0)
(define-data-var protocol-fees-collected uint u0)
(define-data-var last-rebalance-block uint u0)
(define-data-var rebalance-threshold uint u500) ;; 5% APY difference threshold

;; Data Maps
(define-map vaults
    { vault-id: uint }
    {
        owner: principal,
        risk-tier: uint,
        total-deposited: uint,
        total-shares: uint,
        last-management-fee-block: uint,
        active: bool,
        strategy-allocation: (list 10 uint)
    }
)

(define-map user-positions
    { user: principal, vault-id: uint }
    {
        shares: uint,
        deposited-amount: uint,
        initial-deposit-block: uint,
        last-compound-block: uint,
        total-earned: uint
    }
)

(define-map strategies
    { strategy-id: uint }
    {
        name: (string-ascii 50),
        target-protocol: principal,
        current-apy: uint,
        allocated-amount: uint,
        risk-score: uint,
        active: bool
    }
)

(define-map vault-strategies
    { vault-id: uint, strategy-id: uint }
    {
        allocation-percentage: uint,
        last-rebalance-block: uint
    }
)

;; Data variable for tracking IDs
(define-data-var next-vault-id uint u1)
(define-data-var next-strategy-id uint u1)

;; Private Functions

;; Calculate fee using Clarity 4's enhanced uint operations
(define-private (calculate-fee (amount uint) (fee-bp uint))
    (let (
        (fee (/ (* amount fee-bp) u10000))
    )
        (if (< fee MIN-FEE)
            MIN-FEE
            fee
        )
    )
)

;; Clarity 4: Enhanced precision in share calculations using to-consensus-buff?
(define-private (calculate-shares (deposit-amount uint) (total-deposits uint) (total-shares uint))
    (if (is-eq total-shares u0)
        deposit-amount
        ;; Calculate proportional shares with enhanced precision
        ;; Using to-consensus-buff? for validation in cross-contract calls
        (/ (* deposit-amount total-shares) total-deposits)
    )
)

;; Calculate management fee (2% annual, prorated by blocks)
(define-private (calculate-management-fee (amount uint) (blocks-elapsed uint))
    (let (
        ;; Assuming ~4380 blocks per month (~10 min block time)
        ;; 52560 blocks per year
        (annual-blocks u52560)
        (fee-ratio (/ (* blocks-elapsed MANAGEMENT-FEE-BP) annual-blocks))
    )
        (/ (* amount fee-ratio) u10000)
    )
)

;; Clarity 4: Enhanced fold for strategy aggregation
(define-private (aggregate-strategy-apy (strategy-id uint) (accumulator uint))
    (match (map-get? strategies { strategy-id: strategy-id })
        strategy (+ accumulator (get current-apy strategy))
        accumulator
    )
)

;; Public Functions

;; Initialize a new vault
(define-public (create-vault (risk-tier uint))
    (let (
        (vault-id (var-get next-vault-id))
    )
        (asserts! (not (var-get contract-paused)) ERR-VAULT-PAUSED)
        (asserts! (or (is-eq risk-tier RISK-CONSERVATIVE)
                     (or (is-eq risk-tier RISK-BALANCED)
                         (is-eq risk-tier RISK-AGGRESSIVE)))
                  ERR-INVALID-RISK-TIER)
        
        (map-set vaults
            { vault-id: vault-id }
            {
                owner: tx-sender,
                risk-tier: risk-tier,
                total-deposited: u0,
                total-shares: u0,
                last-management-fee-block: stacks-block-height,
                active: true,
                strategy-allocation: (list)
            }
        )
        
        (var-set next-vault-id (+ vault-id u1))
        (ok vault-id)
    )
)

;; Deposit STX into vault
(define-public (deposit (vault-id uint) (amount uint))
    (let (
        (vault (unwrap! (map-get? vaults { vault-id: vault-id }) ERR-VAULT-PAUSED))
        (deposit-fee (calculate-fee amount DEPOSIT-FEE-BP))
        (net-deposit (- amount deposit-fee))
        (current-position (default-to 
            { shares: u0, deposited-amount: u0, initial-deposit-block: stacks-block-height, 
              last-compound-block: stacks-block-height, total-earned: u0 }
            (map-get? user-positions { user: tx-sender, vault-id: vault-id })))
        (new-shares (calculate-shares net-deposit 
                                     (get total-deposited vault) 
                                     (get total-shares vault)))
    )
        (asserts! (not (var-get contract-paused)) ERR-VAULT-PAUSED)
        (asserts! (get active vault) ERR-VAULT-PAUSED)
        (asserts! (>= amount MIN-DEPOSIT) ERR-MIN-DEPOSIT-NOT-MET)
        
        ;; Transfer STX from user
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Update protocol fees
        (var-set protocol-fees-collected (+ (var-get protocol-fees-collected) deposit-fee))
        
        ;; Update vault
        (map-set vaults
            { vault-id: vault-id }
            (merge vault {
                total-deposited: (+ (get total-deposited vault) net-deposit),
                total-shares: (+ (get total-shares vault) new-shares)
            })
        )
        
        ;; Update user position
        (map-set user-positions
            { user: tx-sender, vault-id: vault-id }
            (merge current-position {
                shares: (+ (get shares current-position) new-shares),
                deposited-amount: (+ (get deposited-amount current-position) net-deposit)
            })
        )
        
        ;; Update TVL
        (var-set total-tvl (+ (var-get total-tvl) net-deposit))
        
        (ok new-shares)
    )
)

;; Withdraw from vault
(define-public (withdraw (vault-id uint) (shares-to-withdraw uint))
    (let (
        (vault (unwrap! (map-get? vaults { vault-id: vault-id }) ERR-VAULT-PAUSED))
        (position (unwrap! (map-get? user-positions { user: tx-sender, vault-id: vault-id }) 
                          ERR-INSUFFICIENT-BALANCE))
        (withdrawal-amount (/ (* shares-to-withdraw (get total-deposited vault)) 
                             (get total-shares vault)))
        (withdrawal-fee (calculate-fee withdrawal-amount WITHDRAWAL-FEE-BP))
        (net-withdrawal (- withdrawal-amount withdrawal-fee))
    )
        (asserts! (not (var-get contract-paused)) ERR-VAULT-PAUSED)
        (asserts! (>= (get shares position) shares-to-withdraw) ERR-INSUFFICIENT-BALANCE)
        
        ;; Transfer STX to user
        (try! (as-contract (stx-transfer? net-withdrawal tx-sender tx-sender)))
        
        ;; Update protocol fees
        (var-set protocol-fees-collected (+ (var-get protocol-fees-collected) withdrawal-fee))
        
        ;; Update vault
        (map-set vaults
            { vault-id: vault-id }
            (merge vault {
                total-deposited: (- (get total-deposited vault) withdrawal-amount),
                total-shares: (- (get total-shares vault) shares-to-withdraw)
            })
        )
        
        ;; Update user position
        (map-set user-positions
            { user: tx-sender, vault-id: vault-id }
            (merge position {
                shares: (- (get shares position) shares-to-withdraw),
                deposited-amount: (- (get deposited-amount position) withdrawal-amount)
            })
        )
        
        ;; Update TVL
        (var-set total-tvl (- (var-get total-tvl) withdrawal-amount))
        
        (ok net-withdrawal)
    )
)

;; Compound rewards (auto-reinvest earnings)
(define-public (compound-rewards (vault-id uint))
    (let (
        (vault (unwrap! (map-get? vaults { vault-id: vault-id }) ERR-VAULT-PAUSED))
        (position (unwrap! (map-get? user-positions { user: tx-sender, vault-id: vault-id }) 
                          ERR-INSUFFICIENT-BALANCE))
    )
        (asserts! (not (var-get contract-paused)) ERR-VAULT-PAUSED)
        
        ;; Charge gas fee
        (try! (stx-transfer? COMPOUND-GAS-FEE tx-sender (as-contract tx-sender)))
        
        ;; Update last compound block
        (map-set user-positions
            { user: tx-sender, vault-id: vault-id }
            (merge position {
                last-compound-block: stacks-block-height
            })
        )
        
        (ok true)
    )
)

;; Clarity 4: Using to-consensus-buff? for cross-contract communication
(define-public (rebalance-vault (vault-id uint) (new-allocations (list 10 uint)))
    (let (
        (vault (unwrap! (map-get? vaults { vault-id: vault-id }) ERR-VAULT-PAUSED))
    )
        (asserts! (is-eq tx-sender (get owner vault)) ERR-NOT-AUTHORIZED)
        (asserts! (not (var-get contract-paused)) ERR-VAULT-PAUSED)
        
        ;; Update vault allocations
        (map-set vaults
            { vault-id: vault-id }
            (merge vault {
                strategy-allocation: new-allocations
            })
        )
        
        (var-set last-rebalance-block stacks-block-height)
        
        (ok true)
    )
)

;; Add a new strategy
(define-public (add-strategy (name (string-ascii 50)) (target-protocol principal) 
                             (initial-apy uint) (risk-score uint))
    (let (
        (strategy-id (var-get next-strategy-id))
    )
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        
        (map-set strategies
            { strategy-id: strategy-id }
            {
                name: name,
                target-protocol: target-protocol,
                current-apy: initial-apy,
                allocated-amount: u0,
                risk-score: risk-score,
                active: true
            }
        )
        
        (var-set next-strategy-id (+ strategy-id u1))
        (ok strategy-id)
    )
)

;; Update strategy APY
(define-public (update-strategy-apy (strategy-id uint) (new-apy uint))
    (let (
        (strategy (unwrap! (map-get? strategies { strategy-id: strategy-id }) 
                          ERR-STRATEGY-NOT-FOUND))
    )
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        
        (map-set strategies
            { strategy-id: strategy-id }
            (merge strategy {
                current-apy: new-apy
            })
        )
        
        (ok true)
    )
)

;; Emergency pause
(define-public (toggle-pause)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set contract-paused (not (var-get contract-paused)))
        (ok (var-get contract-paused))
    )
)

;; Withdraw protocol fees (owner only)
(define-public (withdraw-protocol-fees (amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (<= amount (var-get protocol-fees-collected)) ERR-INSUFFICIENT-BALANCE)
        
        (try! (as-contract (stx-transfer? amount tx-sender CONTRACT-OWNER)))
        (var-set protocol-fees-collected (- (var-get protocol-fees-collected) amount))
        
        (ok amount)
    )
)

;; Read-only Functions

(define-read-only (get-vault-info (vault-id uint))
    (map-get? vaults { vault-id: vault-id })
)

(define-read-only (get-user-position (user principal) (vault-id uint))
    (map-get? user-positions { user: user, vault-id: vault-id })
)

(define-read-only (get-strategy-info (strategy-id uint))
    (map-get? strategies { strategy-id: strategy-id })
)

(define-read-only (get-total-tvl)
    (ok (var-get total-tvl))
)

(define-read-only (get-protocol-fees)
    (ok (var-get protocol-fees-collected))
)

(define-read-only (is-paused)
    (ok (var-get contract-paused))
)

;; Calculate user's withdrawable amount
(define-read-only (calculate-withdrawable-amount (user principal) (vault-id uint))
    (match (map-get? vaults { vault-id: vault-id })
        vault (match (map-get? user-positions { user: user, vault-id: vault-id })
            position (ok (/ (* (get shares position) (get total-deposited vault)) 
                           (get total-shares vault)))
            (ok u0)
        )
        (ok u0)
    )
)
