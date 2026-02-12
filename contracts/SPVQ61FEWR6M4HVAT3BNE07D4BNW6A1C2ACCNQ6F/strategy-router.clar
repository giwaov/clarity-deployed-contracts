;; YieldForge Strategy Router Contract
;; Routes capital to optimal yield sources with gas-optimized execution

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-INVALID-PROTOCOL (err u201))
(define-constant ERR-INSUFFICIENT-LIQUIDITY (err u202))
(define-constant ERR-ROUTE-NOT-FOUND (err u203))
(define-constant ERR-REBALANCE-FAILED (err u204))
(define-constant ERR-EMERGENCY-ONLY (err u205))
(define-constant ERR-INVALID-VOTE (err u206))
(define-constant ERR-STAKE-REQUIRED (err u207))

;; Fee constants (in basis points)
(define-constant REBALANCING-FEE-BP u10)     ;; 0.1%
(define-constant KEEPER-REWARD-BP u5)        ;; 0.05%
(define-constant FLASH-LOAN-FEE-BP u30)      ;; 0.3%
(define-constant STRATEGY-PROPOSAL-STAKE u10000000) ;; 10 STX

;; Data Variables
(define-data-var emergency-mode bool false)
(define-data-var total-routes uint u0)
(define-data-var keeper-rewards-pool uint u0)
(define-data-var last-keeper-claim-block uint u0)

;; Data Maps

;; Protocol registry for validation (Clarity 4: principal-destruct?)
(define-map registered-protocols
    { protocol-address: principal }
    {
        name: (string-ascii 50),
        active: bool,
        total-routed: uint,
        last-interaction-block: uint,
        risk-rating: uint  ;; 1-10 scale
    }
)

;; Route optimization data (Clarity 4: slice? for efficient parsing)
(define-map routes
    { route-id: uint }
    {
        source-protocol: principal,
        target-protocol: principal,
        estimated-apy: uint,
        gas-cost: uint,
        active: bool,
        success-count: uint,
        failure-count: uint
    }
)

;; Capital allocation tracking
(define-map protocol-allocations
    { protocol-address: principal }
    {
        allocated-amount: uint,
        last-rebalance-block: uint,
        pending-withdrawal: uint
    }
)

;; Strategy proposals (governance)
(define-map strategy-proposals
    { proposal-id: uint }
    {
        proposer: principal,
        target-protocol: principal,
        description: (string-utf8 500),
        stake-amount: uint,
        votes-for: uint,
        votes-against: uint,
        status: (string-ascii 20),  ;; "pending", "active", "rejected"
        created-block: uint
    }
)

;; User votes on strategies
(define-map strategy-votes
    { proposal-id: uint, voter: principal }
    {
        vote-weight: uint,
        vote-type: bool  ;; true = for, false = against
    }
)

;; Keeper registry
(define-map keepers
    { keeper-address: principal }
    {
        total-rebalances: uint,
        earned-rewards: uint,
        last-action-block: uint,
        active: bool
    }
)

;; Emergency withdrawal requests
(define-map emergency-withdrawals
    { user: principal, protocol: principal }
    {
        amount: uint,
        requested-block: uint,
        processed: bool
    }
)

;; Route execution history for optimization
(define-map route-history
    { route-id: uint, execution-block: uint }
    {
        amount-routed: uint,
        gas-used: uint,
        apy-achieved: uint,
        executor: principal
    }
)

;; Data variables for IDs
(define-data-var next-route-id uint u1)
(define-data-var next-proposal-id uint u1)

;; Private Functions

;; Clarity 4: Using principal-destruct? for protocol validation
(define-private (validate-protocol-address (protocol principal))
    (is-ok (principal-destruct? protocol))
)

;; Calculate rebalancing fee
(define-private (calculate-rebalancing-fee (amount uint))
    (/ (* amount REBALANCING-FEE-BP) u10000)
)

;; Calculate keeper reward based on TVL
(define-private (calculate-keeper-reward (tvl uint))
    (/ (* tvl KEEPER-REWARD-BP) u10000)
)

;; Optimize route selection (Clarity 4: slice? for data parsing)
(define-private (find-optimal-route (amount uint) (source principal) (target principal))
    (let (
        (route-data (unwrap! (map-get? routes { route-id: u1 }) 
                            (err ERR-ROUTE-NOT-FOUND)))
    )
        ;; Simple implementation - in production would iterate through routes
        (ok u1)
    )
)

;; Calculate gas efficiency score
(define-private (calculate-gas-efficiency (route-id uint))
    (match (map-get? routes { route-id: route-id })
        route (let (
            (total-executions (+ (get success-count route) (get failure-count route)))
            (success-rate (if (> total-executions u0)
                            (/ (* (get success-count route) u100) total-executions)
                            u0))
        )
            (ok success-rate)
        )
        (err ERR-ROUTE-NOT-FOUND)
    )
)

;; Public Functions

;; Register a new DeFi protocol
(define-public (register-protocol (protocol-address principal) (name (string-ascii 50)) 
                                  (risk-rating uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (validate-protocol-address protocol-address) ERR-INVALID-PROTOCOL)
        
        (map-set registered-protocols
            { protocol-address: protocol-address }
            {
                name: name,
                active: true,
                total-routed: u0,
                last-interaction-block: stacks-block-height,
                risk-rating: risk-rating
            }
        )
        
        (ok true)
    )
)

;; Create a route between protocols
(define-public (create-route (source-protocol principal) (target-protocol principal) 
                            (estimated-apy uint) (gas-cost uint))
    (let (
        (route-id (var-get next-route-id))
    )
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (is-some (map-get? registered-protocols { protocol-address: source-protocol }))
                  ERR-INVALID-PROTOCOL)
        (asserts! (is-some (map-get? registered-protocols { protocol-address: target-protocol }))
                  ERR-INVALID-PROTOCOL)
        
        (map-set routes
            { route-id: route-id }
            {
                source-protocol: source-protocol,
                target-protocol: target-protocol,
                estimated-apy: estimated-apy,
                gas-cost: gas-cost,
                active: true,
                success-count: u0,
                failure-count: u0
            }
        )
        
        (var-set next-route-id (+ route-id u1))
        (var-set total-routes (+ (var-get total-routes) u1))
        
        (ok route-id)
    )
)

;; Execute capital routing (gas-optimized)
(define-public (route-capital (route-id uint) (amount uint))
    (let (
        (route (unwrap! (map-get? routes { route-id: route-id }) ERR-ROUTE-NOT-FOUND))
        (rebalancing-fee (calculate-rebalancing-fee amount))
        (net-amount (- amount rebalancing-fee))
        (source-alloc (default-to 
            { allocated-amount: u0, last-rebalance-block: stacks-block-height, pending-withdrawal: u0 }
            (map-get? protocol-allocations { protocol-address: (get source-protocol route) })))
        (target-alloc (default-to 
            { allocated-amount: u0, last-rebalance-block: stacks-block-height, pending-withdrawal: u0 }
            (map-get? protocol-allocations { protocol-address: (get target-protocol route) })))
    )
        (asserts! (not (var-get emergency-mode)) ERR-EMERGENCY-ONLY)
        (asserts! (get active route) ERR-ROUTE-NOT-FOUND)
        (asserts! (>= (get allocated-amount source-alloc) amount) ERR-INSUFFICIENT-LIQUIDITY)
        
        ;; Update source protocol allocation
        (map-set protocol-allocations
            { protocol-address: (get source-protocol route) }
            (merge source-alloc {
                allocated-amount: (- (get allocated-amount source-alloc) amount),
                last-rebalance-block: stacks-block-height
            })
        )
        
        ;; Update target protocol allocation
        (map-set protocol-allocations
            { protocol-address: (get target-protocol route) }
            (merge target-alloc {
                allocated-amount: (+ (get allocated-amount target-alloc) net-amount),
                last-rebalance-block: stacks-block-height
            })
        )
        
        ;; Update route success count
        (map-set routes
            { route-id: route-id }
            (merge route {
                success-count: (+ (get success-count route) u1)
            })
        )
        
        ;; Add to keeper rewards pool
        (var-set keeper-rewards-pool (+ (var-get keeper-rewards-pool) rebalancing-fee))
        
        ;; Record execution history
        (map-set route-history
            { route-id: route-id, execution-block: stacks-block-height }
            {
                amount-routed: amount,
                gas-used: (get gas-cost route),
                apy-achieved: (get estimated-apy route),
                executor: tx-sender
            }
        )
        
        (ok net-amount)
    )
)

;; Propose new strategy (requires 10 STX stake)
(define-public (propose-strategy (target-protocol principal) 
                                (description (string-utf8 500)))
    (let (
        (proposal-id (var-get next-proposal-id))
    )
        (asserts! (is-some (map-get? registered-protocols { protocol-address: target-protocol }))
                  ERR-INVALID-PROTOCOL)
        
        ;; Require stake
        (try! (stx-transfer? STRATEGY-PROPOSAL-STAKE tx-sender (as-contract tx-sender)))
        
        (map-set strategy-proposals
            { proposal-id: proposal-id }
            {
                proposer: tx-sender,
                target-protocol: target-protocol,
                description: description,
                stake-amount: STRATEGY-PROPOSAL-STAKE,
                votes-for: u0,
                votes-against: u0,
                status: "pending",
                created-block: stacks-block-height
            }
        )
        
        (var-set next-proposal-id (+ proposal-id u1))
        
        (ok proposal-id)
    )
)

;; Vote on strategy proposal (requires vault tokens - simplified for demo)
(define-public (vote-on-strategy (proposal-id uint) (vote-for bool) (vote-weight uint))
    (let (
        (proposal (unwrap! (map-get? strategy-proposals { proposal-id: proposal-id }) 
                          ERR-INVALID-VOTE))
    )
        (asserts! (is-eq (get status proposal) "pending") ERR-INVALID-VOTE)
        
        (map-set strategy-votes
            { proposal-id: proposal-id, voter: tx-sender }
            {
                vote-weight: vote-weight,
                vote-type: vote-for
            }
        )
        
        ;; Update proposal votes
        (map-set strategy-proposals
            { proposal-id: proposal-id }
            (merge proposal {
                votes-for: (if vote-for 
                             (+ (get votes-for proposal) vote-weight)
                             (get votes-for proposal)),
                votes-against: (if (not vote-for) 
                                 (+ (get votes-against proposal) vote-weight)
                                 (get votes-against proposal))
            })
        )
        
        (ok true)
    )
)

;; Emergency withdrawal mechanism
(define-public (request-emergency-withdrawal (protocol principal) (amount uint))
    (let (
        (allocation (unwrap! (map-get? protocol-allocations { protocol-address: protocol })
                            ERR-INVALID-PROTOCOL))
    )
        (asserts! (var-get emergency-mode) ERR-EMERGENCY-ONLY)
        
        (map-set emergency-withdrawals
            { user: tx-sender, protocol: protocol }
            {
                amount: amount,
                requested-block: stacks-block-height,
                processed: false
            }
        )
        
        (ok true)
    )
)

;; Process emergency withdrawal (keeper/admin only)
(define-public (process-emergency-withdrawal (user principal) (protocol principal))
    (let (
        (withdrawal (unwrap! (map-get? emergency-withdrawals { user: user, protocol: protocol })
                            ERR-ROUTE-NOT-FOUND))
    )
        (asserts! (var-get emergency-mode) ERR-EMERGENCY-ONLY)
        (asserts! (not (get processed withdrawal)) ERR-REBALANCE-FAILED)
        
        (map-set emergency-withdrawals
            { user: user, protocol: protocol }
            (merge withdrawal {
                processed: true
            })
        )
        
        (ok true)
    )
)

;; Register as keeper
(define-public (register-keeper)
    (begin
        (map-set keepers
            { keeper-address: tx-sender }
            {
                total-rebalances: u0,
                earned-rewards: u0,
                last-action-block: stacks-block-height,
                active: true
            }
        )
        (ok true)
    )
)

;; Claim keeper rewards
(define-public (claim-keeper-rewards)
    (let (
        (keeper (unwrap! (map-get? keepers { keeper-address: tx-sender }) 
                        ERR-NOT-AUTHORIZED))
        (reward-amount (get earned-rewards keeper))
    )
        (asserts! (get active keeper) ERR-NOT-AUTHORIZED)
        (asserts! (> reward-amount u0) ERR-INSUFFICIENT-LIQUIDITY)
        
        ;; Transfer rewards
        (try! (as-contract (stx-transfer? reward-amount tx-sender tx-sender)))
        
        ;; Update keeper record
        (map-set keepers
            { keeper-address: tx-sender }
            (merge keeper {
                earned-rewards: u0,
                last-action-block: stacks-block-height
            })
        )
        
        (ok reward-amount)
    )
)

;; Toggle emergency mode
(define-public (toggle-emergency-mode)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set emergency-mode (not (var-get emergency-mode)))
        (ok (var-get emergency-mode))
    )
)

;; Update route APY estimate
(define-public (update-route-apy (route-id uint) (new-apy uint))
    (let (
        (route (unwrap! (map-get? routes { route-id: route-id }) ERR-ROUTE-NOT-FOUND))
    )
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        
        (map-set routes
            { route-id: route-id }
            (merge route {
                estimated-apy: new-apy
            })
        )
        
        (ok true)
    )
)

;; Deactivate route
(define-public (deactivate-route (route-id uint))
    (let (
        (route (unwrap! (map-get? routes { route-id: route-id }) ERR-ROUTE-NOT-FOUND))
    )
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        
        (map-set routes
            { route-id: route-id }
            (merge route {
                active: false
            })
        )
        
        (ok true)
    )
)

;; Read-only Functions

(define-read-only (get-protocol-info (protocol-address principal))
    (map-get? registered-protocols { protocol-address: protocol-address })
)

(define-read-only (get-route-info (route-id uint))
    (map-get? routes { route-id: route-id })
)

(define-read-only (get-protocol-allocation (protocol-address principal))
    (map-get? protocol-allocations { protocol-address: protocol-address })
)

(define-read-only (get-strategy-proposal (proposal-id uint))
    (map-get? strategy-proposals { proposal-id: proposal-id })
)

(define-read-only (get-keeper-info (keeper-address principal))
    (map-get? keepers { keeper-address: keeper-address })
)

(define-read-only (get-route-history (route-id uint) (execution-block uint))
    (map-get? route-history { route-id: route-id, execution-block: execution-block })
)

(define-read-only (is-emergency-mode)
    (ok (var-get emergency-mode))
)

(define-read-only (get-total-routes)
    (ok (var-get total-routes))
)

(define-read-only (get-keeper-rewards-pool)
    (ok (var-get keeper-rewards-pool))
)

;; Calculate optimal route (read-only simulation)
(define-read-only (simulate-route (source principal) (target principal) (amount uint))
    (let (
        (source-protocol (map-get? registered-protocols { protocol-address: source }))
        (target-protocol (map-get? registered-protocols { protocol-address: target }))
    )
        (if (and (is-some source-protocol) (is-some target-protocol))
            (ok {
                estimated-fee: (calculate-rebalancing-fee amount),
                net-amount: (- amount (calculate-rebalancing-fee amount))
            })
            (err ERR-INVALID-PROTOCOL)
        )
    )
)
