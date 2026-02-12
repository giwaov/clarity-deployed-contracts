;; Payment Handler Contract
;; Manages deposits, releases, and refunds of funds for bookings
;; Supports both native STX and SIP-010 fungible tokens (sBTC, USDT, USDC)
;; Includes DAO Agent Fee support for AI-powered host assistance services

;; Import SIP-010 trait
;; For local Clarinet: (use-trait sip-010-trait .sip-010-trait.sip-010-trait)
;; For testnet: (use-trait sip-010-trait 'ST1NXBK3K5YYMD6FD41MVNP3JS1GABZ8TRVX023PT.sip-010-trait-ft-standard.sip-010-trait)
;; For MAINNET deployment:
(use-trait sip-010-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; --- Constants ---

(define-constant ERR-UNAUTHORIZED (err u3001))
(define-constant ERR-BOOKING-NOT-FOUND (err u3002))
(define-constant ERR-INSUFFICIENT-FUNDS (err u3003))
(define-constant ERR-INVALID-TOKEN (err u3004))
(define-constant ERR-INVALID-STATE (err u3005))
(define-constant ERR-INVALID-AMOUNT (err u3006))
(define-constant ERR-TRANSFER-FAILED (err u3007))
(define-constant ERR-TOKEN-NOT-SUPPORTED (err u3008))
(define-constant ERR-TOKEN-ALREADY-REGISTERED (err u3009))
(define-constant ERR-NOT-ADMIN (err u3010))
(define-constant ERR-AGENT-FEE-ALREADY-SET (err u3011))
(define-constant ERR-INVALID-TREASURY (err u3012))

;; STX token identifier (special constant for native token)
(define-constant STX-TOKEN 'SP000000000000000000002Q6VF78.stx)

;; Contract deployer (admin)
(define-constant CONTRACT-DEPLOYER tx-sender)

;; --- Data Variables ---

;; Total service fee rate (basis points, e.g., 300 = 3%)
;; This is split 50/50 between Platform DAO and Community DAO
(define-data-var service-fee-rate uint u300)

;; Agent fee rate (basis points, e.g., 100 = 1%)
;; Additional fee when AI agent services are used
;; Goes 100% to Platform DAO (covers LLM, SMS, Email infrastructure costs)
(define-data-var agent-fee-rate uint u100)

;; Fee split percentage for Community DAO on SERVICE fees (basis points, 5000 = 50%)
;; Platform DAO gets the remainder of service fees
(define-data-var community-fee-split uint u5000)

;; Fee split percentage for Community DAO on AGENT fees (basis points, 0 = 0%)
;; Agent fees go 100% to Platform DAO by default (covers infrastructure costs)
(define-data-var agent-fee-community-split uint u0)

;; Platform DAO Treasury address - receives platform's share of fees
(define-data-var platform-treasury principal CONTRACT-DEPLOYER)

;; Community DAO Treasury address - receives community's share of fees
;; Each listing can override this with their specific community DAO
(define-data-var default-community-treasury principal CONTRACT-DEPLOYER)

;; Admin principal
(define-data-var admin principal CONTRACT-DEPLOYER)

;; --- Data Maps ---

;; Supported SIP-010 tokens registry
(define-map supported-tokens
    principal  ;; token contract address
    {
        symbol: (string-ascii 10),
        decimals: uint,
        is-stablecoin: bool,
        is-active: bool
    }
)

;; Escrow balance for a booking (by token)
(define-map escrow-balances
    { booking-id: uint, token: principal }
    uint
)

;; Escrow status for a booking
(define-map escrow-status
    uint
    {
        deposited: bool,
        released: bool,
        refunded: bool,
        total-deposited: uint,
        guest: principal,
        host: principal,
        token: principal,
        is-stx: bool,        ;; true if payment is in native STX
        usd-amount: uint,    ;; Original USD amount (in cents, e.g., 45000 = $450.00)
        agent-fee: uint,     ;; Agent service fee for this booking (in micro-STX or token units)
        agent-used: bool,    ;; Whether agent services were used for this booking
        community-treasury: principal  ;; Community DAO treasury for this booking (if applicable)
    }
)

;; Agent usage tracking per booking
(define-map booking-agent-usage
    uint  ;; booking-id
    {
        llm-calls: uint,           ;; Number of LLM API calls made
        auto-responses: uint,      ;; Number of automated responses sent
        service-requests: uint,    ;; Number of service provider requests
        last-activity: uint        ;; Block height of last agent activity
    }
)

;; --- Admin Functions ---

;; @desc Register a new supported SIP-010 token
(define-public (register-token 
    (token-contract principal)
    (symbol (string-ascii 10))
    (decimals uint)
    (is-stablecoin bool)
)
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-ADMIN)
        (asserts! (is-none (map-get? supported-tokens token-contract)) ERR-TOKEN-ALREADY-REGISTERED)
        (map-set supported-tokens token-contract {
            symbol: symbol,
            decimals: decimals,
            is-stablecoin: is-stablecoin,
            is-active: true
        })
        (print { event: "token-registered", token: token-contract, symbol: symbol })
        (ok true)
    )
)

;; @desc Deactivate a supported token
(define-public (deactivate-token (token-contract principal))
    (let ((token-info (unwrap! (map-get? supported-tokens token-contract) ERR-TOKEN-NOT-SUPPORTED)))
        (begin
            (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-ADMIN)
            (map-set supported-tokens token-contract (merge token-info { is-active: false }))
            (print { event: "token-deactivated", token: token-contract })
            (ok true)
        )
    )
)

;; @desc Update service fee rate (admin only)
(define-public (set-service-fee-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-ADMIN)
        (asserts! (<= new-rate u1000) ERR-INVALID-AMOUNT) ;; Max 10%
        (var-set service-fee-rate new-rate)
        (print { event: "fee-rate-updated", new-rate: new-rate })
        (ok true)
    )
)

;; @desc Transfer admin rights
(define-public (set-admin (new-admin principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-ADMIN)
        (var-set admin new-admin)
        (print { event: "admin-updated", new-admin: new-admin })
        (ok true)
    )
)

;; @desc Update DAO treasury address (admin only)
;; @desc Update Platform DAO treasury address (admin only)
(define-public (set-platform-treasury (new-treasury principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-ADMIN)
        (var-set platform-treasury new-treasury)
        (print { event: "platform-treasury-updated", new-treasury: new-treasury })
        (ok true)
    )
)

;; @desc Update default Community DAO treasury address (admin only)
(define-public (set-default-community-treasury (new-treasury principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-ADMIN)
        (var-set default-community-treasury new-treasury)
        (print { event: "default-community-treasury-updated", new-treasury: new-treasury })
        (ok true)
    )
)

;; @desc Update fee split percentage for Community DAO on SERVICE fees (admin only)
;; Default is 5000 = 50%, meaning community gets half, platform gets half
(define-public (set-community-fee-split (new-split uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-ADMIN)
        (asserts! (<= new-split u10000) ERR-INVALID-AMOUNT) ;; Max 100%
        (var-set community-fee-split new-split)
        (print { event: "community-fee-split-updated", new-split: new-split })
        (ok true)
    )
)

;; @desc Update fee split percentage for Community DAO on AGENT fees (admin only)
;; Default is 0 = 0%, meaning platform gets 100% of agent fees (covers infrastructure)
(define-public (set-agent-fee-community-split (new-split uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-ADMIN)
        (asserts! (<= new-split u10000) ERR-INVALID-AMOUNT) ;; Max 100%
        (var-set agent-fee-community-split new-split)
        (print { event: "agent-fee-community-split-updated", new-split: new-split })
        (ok true)
    )
)

;; @desc Update agent fee rate (admin only, DAO governance)
(define-public (set-agent-fee-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-ADMIN)
        (asserts! (<= new-rate u500) ERR-INVALID-AMOUNT) ;; Max 5%
        (var-set agent-fee-rate new-rate)
        (print { event: "agent-fee-rate-updated", new-rate: new-rate })
        (ok true)
    )
)

;; @desc Set agent fee for a specific booking (admin/platform only)
;; Called when host uses agent services for a booking
(define-public (set-booking-agent-fee (booking-id uint) (fee uint))
    (let ((status (unwrap! (map-get? escrow-status booking-id) ERR-BOOKING-NOT-FOUND)))
        (begin
            ;; Only admin or host can set agent fee
            (asserts! (or (is-eq tx-sender (var-get admin)) (is-eq tx-sender (get host status))) ERR-UNAUTHORIZED)
            ;; Cannot set fee after release
            (asserts! (not (get released status)) ERR-INVALID-STATE)
            ;; Fee cannot exceed total deposit
            (asserts! (<= fee (get total-deposited status)) ERR-INVALID-AMOUNT)
            
            ;; Update escrow status with agent fee
            (map-set escrow-status booking-id 
                (merge status { 
                    agent-fee: fee,
                    agent-used: true 
                })
            )
            (print { 
                event: "agent-fee-set", 
                booking-id: booking-id, 
                fee: fee 
            })
            (ok true)
        )
    )
)

;; @desc Enable agent services for a booking using default rate
;; Calculates fee based on current agent-fee-rate
(define-public (enable-agent-for-booking (booking-id uint))
    (let (
        (status (unwrap! (map-get? escrow-status booking-id) ERR-BOOKING-NOT-FOUND))
        (total (get total-deposited status))
        (rate (var-get agent-fee-rate))
        (calculated-fee (/ (* total rate) u10000))
    )
        (begin
            ;; Only admin or host can enable agent
            (asserts! (or (is-eq tx-sender (var-get admin)) (is-eq tx-sender (get host status))) ERR-UNAUTHORIZED)
            ;; Cannot enable after release
            (asserts! (not (get released status)) ERR-INVALID-STATE)
            ;; Cannot re-enable if already set
            (asserts! (not (get agent-used status)) ERR-AGENT-FEE-ALREADY-SET)
            
            ;; Update escrow status with calculated agent fee
            (map-set escrow-status booking-id 
                (merge status { 
                    agent-fee: calculated-fee,
                    agent-used: true 
                })
            )
            (print { 
                event: "agent-enabled", 
                booking-id: booking-id, 
                fee: calculated-fee,
                rate: rate 
            })
            (ok calculated-fee)
        )
    )
)

;; @desc Record agent usage for a booking (for tracking purposes)
(define-public (record-agent-usage 
    (booking-id uint)
    (llm-calls uint)
    (auto-responses uint)
    (service-requests uint)
)
    (let ((status (unwrap! (map-get? escrow-status booking-id) ERR-BOOKING-NOT-FOUND)))
        (begin
            ;; Only admin or host can record usage
            (asserts! (or (is-eq tx-sender (var-get admin)) (is-eq tx-sender (get host status))) ERR-UNAUTHORIZED)
            
            ;; Get current usage or default
            (let ((current-usage (default-to {
                    llm-calls: u0,
                    auto-responses: u0,
                    service-requests: u0,
                    last-activity: u0
                } (map-get? booking-agent-usage booking-id))))
                (map-set booking-agent-usage booking-id {
                    llm-calls: (+ (get llm-calls current-usage) llm-calls),
                    auto-responses: (+ (get auto-responses current-usage) auto-responses),
                    service-requests: (+ (get service-requests current-usage) service-requests),
                    last-activity: stacks-block-height
                })
            )
            (print { 
                event: "agent-usage-recorded", 
                booking-id: booking-id,
                llm-calls: llm-calls,
                auto-responses: auto-responses,
                service-requests: service-requests
            })
            (ok true)
        )
    )
)

;; --- Deposit Functions ---

;; @desc Deposits native STX into escrow for a booking
;; @param community-treasury - Optional community DAO treasury for this booking
(define-public (deposit-stx
    (booking-id uint)
    (amount uint)
    (guest principal)
    (host principal)
    (usd-amount uint)
)
    (deposit-stx-with-community booking-id amount guest host usd-amount (var-get default-community-treasury))
)

;; @desc Deposits native STX into escrow with specific community DAO
(define-public (deposit-stx-with-community
    (booking-id uint)
    (amount uint)
    (guest principal)
    (host principal)
    (usd-amount uint)
    (community-treasury principal)
)
    (let ((sender tx-sender))
        (begin
            ;; Validate amount
            (asserts! (> amount u0) ERR-INVALID-AMOUNT)
            ;; Verify sender is the guest
            (asserts! (is-eq sender guest) ERR-UNAUTHORIZED)
            
            ;; Transfer STX from sender to this contract
            (match (stx-transfer? amount sender (as-contract tx-sender))
                success (begin
                    ;; Record deposit
                    (let ((balance-key { booking-id: booking-id, token: STX-TOKEN })
                          (current-balance (default-to u0 (map-get? escrow-balances balance-key))))
                        (map-set escrow-balances balance-key (+ current-balance amount))
                        
                        (let ((status (default-to {
                                deposited: false,
                                released: false,
                                refunded: false,
                                total-deposited: u0,
                                guest: guest,
                                host: host,
                                token: STX-TOKEN,
                                is-stx: true,
                                usd-amount: u0,
                                agent-fee: u0,
                                agent-used: false,
                                community-treasury: (var-get default-community-treasury)
                            } (map-get? escrow-status booking-id))))
                            (map-set escrow-status booking-id {
                                deposited: true,
                                released: (get released status),
                                refunded: (get refunded status),
                                total-deposited: (+ (get total-deposited status) amount),
                                guest: guest,
                                host: host,
                                token: STX-TOKEN,
                                is-stx: true,
                                usd-amount: usd-amount,
                                agent-fee: (get agent-fee status),
                                agent-used: (get agent-used status),
                                community-treasury: community-treasury
                            })
                        )
                        
                        (print { 
                            event: "stx-deposited", 
                            booking-id: booking-id, 
                            amount: amount,
                            usd-amount: usd-amount,
                            depositor: sender,
                            community-treasury: community-treasury
                        })
                        (ok true)
                    )
                )
                error ERR-TRANSFER-FAILED
            )
        )
    )
)

;; @desc Deposits SIP-010 token into escrow for a booking
(define-public (deposit-sip010
    (booking-id uint)
    (amount uint)
    (token <sip-010-trait>)
    (guest principal)
    (host principal)
    (usd-amount uint)
)
    (deposit-sip010-with-community booking-id amount token guest host usd-amount (var-get default-community-treasury))
)

;; @desc Deposits SIP-010 token into escrow with specific community DAO
(define-public (deposit-sip010-with-community
    (booking-id uint)
    (amount uint)
    (token <sip-010-trait>)
    (guest principal)
    (host principal)
    (usd-amount uint)
    (community-treasury principal)
)
    (let (
        (sender tx-sender)
        (token-contract (contract-of token))
        (token-info (unwrap! (map-get? supported-tokens token-contract) ERR-TOKEN-NOT-SUPPORTED))
    )
        (begin
            ;; Validate token is active
            (asserts! (get is-active token-info) ERR-TOKEN-NOT-SUPPORTED)
            ;; Validate amount
            (asserts! (> amount u0) ERR-INVALID-AMOUNT)
            ;; Verify sender is the guest
            (asserts! (is-eq sender guest) ERR-UNAUTHORIZED)
            
            ;; Transfer token from sender to this contract
            (match (contract-call? token transfer amount sender (as-contract tx-sender) none)
                success (begin
                    ;; Record deposit
                    (let ((balance-key { booking-id: booking-id, token: token-contract })
                          (current-balance (default-to u0 (map-get? escrow-balances balance-key))))
                        (map-set escrow-balances balance-key (+ current-balance amount))
                        
                        (let ((status (default-to {
                                deposited: false,
                                released: false,
                                refunded: false,
                                total-deposited: u0,
                                guest: guest,
                                host: host,
                                token: token-contract,
                                is-stx: false,
                                usd-amount: u0,
                                agent-fee: u0,
                                agent-used: false,
                                community-treasury: (var-get default-community-treasury)
                            } (map-get? escrow-status booking-id))))
                            (map-set escrow-status booking-id {
                                deposited: true,
                                released: (get released status),
                                refunded: (get refunded status),
                                total-deposited: (+ (get total-deposited status) amount),
                                guest: guest,
                                host: host,
                                token: token-contract,
                                is-stx: false,
                                usd-amount: usd-amount,
                                agent-fee: (get agent-fee status),
                                agent-used: (get agent-used status),
                                community-treasury: community-treasury
                            })
                        )
                        
                        (print { 
                            event: "sip010-deposited", 
                            booking-id: booking-id, 
                            amount: amount,
                            usd-amount: usd-amount,
                            token: token-contract,
                            symbol: (get symbol token-info),
                            depositor: sender,
                            community-treasury: community-treasury
                        })
                        (ok true)
                    )
                )
                error ERR-TRANSFER-FAILED
            )
        )
    )
)

;; --- Release Functions ---

;; @desc Releases STX funds from escrow to the host
;; Deducts service fee (3%) and agent fee (1%) if applicable
;; Service fees split per community-fee-split (default 50/50)
;; Agent fees split per agent-fee-community-split (default 100% to Platform)
(define-public (release-stx (booking-id uint))
    (let ((status (unwrap! (map-get? escrow-status booking-id) ERR-BOOKING-NOT-FOUND))
          (sender tx-sender))
        (begin
            ;; Verify is STX payment
            (asserts! (get is-stx status) ERR-INVALID-TOKEN)
            ;; Verify sender is host
            (asserts! (is-eq sender (get host status)) ERR-UNAUTHORIZED)
            ;; Verify funds are deposited and not already released
            (asserts! (get deposited status) ERR-INVALID-STATE)
            (asserts! (not (get released status)) ERR-INVALID-STATE)
            
            ;; Calculate fees with separate splits for service and agent fees
            (let (
                (total-deposited (get total-deposited status))
                (fee-rate (var-get service-fee-rate))  ;; 300 = 3%
                (service-fee (/ (* total-deposited fee-rate) u10000))
                (agent-fee (get agent-fee status))
                (total-fees (+ service-fee agent-fee))
                (host-amount (- total-deposited total-fees))
                (host (get host status))
                ;; Split SERVICE fees per community-fee-split (default 50/50)
                (service-split-rate (var-get community-fee-split))  ;; 5000 = 50%
                (service-community-share (/ (* service-fee service-split-rate) u10000))
                (service-platform-share (- service-fee service-community-share))
                ;; Split AGENT fees per agent-fee-community-split (default 0% to community)
                (agent-split-rate (var-get agent-fee-community-split))  ;; 0 = 0%
                (agent-community-share (/ (* agent-fee agent-split-rate) u10000))
                (agent-platform-share (- agent-fee agent-community-share))
                ;; Total shares
                (community-share (+ service-community-share agent-community-share))
                (platform-share (+ service-platform-share agent-platform-share))
                (platform-dest (var-get platform-treasury))
                (community-dest (get community-treasury status))
            )
                ;; Transfer host-amount to host
                (match (as-contract (stx-transfer? host-amount tx-sender host))
                    host-success (begin
                        ;; Transfer platform share to Platform DAO treasury
                        (if (> platform-share u0)
                            (match (as-contract (stx-transfer? platform-share tx-sender platform-dest))
                                platform-success (begin
                                    ;; Transfer community share to Community DAO treasury
                                    (if (> community-share u0)
                                        (match (as-contract (stx-transfer? community-share tx-sender community-dest))
                                            community-success (begin
                                                (map-set escrow-status booking-id (merge status { released: true }))
                                                (print { 
                                                    event: "stx-released", 
                                                    booking-id: booking-id, 
                                                    host-amount: host-amount, 
                                                    service-fee: service-fee,
                                                    agent-fee: agent-fee,
                                                    total-fees: total-fees,
                                                    platform-share: platform-share,
                                                    community-share: community-share,
                                                    platform-treasury: platform-dest,
                                                    community-treasury: community-dest
                                                })
                                                (ok true)
                                            )
                                            community-error ERR-TRANSFER-FAILED
                                        )
                                        ;; No community share - mark as released
                                        (begin
                                            (map-set escrow-status booking-id (merge status { released: true }))
                                            (print { 
                                                event: "stx-released", 
                                                booking-id: booking-id, 
                                                host-amount: host-amount, 
                                                service-fee: service-fee,
                                                agent-fee: agent-fee,
                                                total-fees: total-fees,
                                                platform-share: platform-share,
                                                community-share: u0,
                                                platform-treasury: platform-dest,
                                                community-treasury: community-dest
                                            })
                                            (ok true)
                                        )
                                    )
                                )
                                platform-error ERR-TRANSFER-FAILED
                            )
                            ;; No platform share (shouldn't happen but handle gracefully)
                            (begin
                                (map-set escrow-status booking-id (merge status { released: true }))
                                (print { 
                                    event: "stx-released", 
                                    booking-id: booking-id, 
                                    host-amount: host-amount, 
                                    service-fee: service-fee,
                                    agent-fee: agent-fee,
                                    total-fees: total-fees,
                                    platform-share: u0,
                                    community-share: u0,
                                    platform-treasury: platform-dest,
                                    community-treasury: community-dest
                                })
                                (ok true)
                            )
                        )
                    )
                    host-error ERR-TRANSFER-FAILED
                )
            )
        )
    )
)

;; @desc Releases SIP-010 token funds from escrow to the host
;; Deducts service fee (3%) and agent fee (1%) if applicable
;; Service fees split per community-fee-split (default 50/50)
;; Agent fees split per agent-fee-community-split (default 100% to Platform)
(define-public (release-sip010 (booking-id uint) (token <sip-010-trait>))
    (let (
        (status (unwrap! (map-get? escrow-status booking-id) ERR-BOOKING-NOT-FOUND))
        (sender tx-sender)
        (token-contract (contract-of token))
    )
        (begin
            ;; Verify token matches booking
            (asserts! (is-eq token-contract (get token status)) ERR-INVALID-TOKEN)
            ;; Verify is NOT STX payment
            (asserts! (not (get is-stx status)) ERR-INVALID-TOKEN)
            ;; Verify sender is host
            (asserts! (is-eq sender (get host status)) ERR-UNAUTHORIZED)
            ;; Verify funds are deposited and not already released
            (asserts! (get deposited status) ERR-INVALID-STATE)
            (asserts! (not (get released status)) ERR-INVALID-STATE)
            
            ;; Calculate fees with separate splits for service and agent fees
            (let (
                (total-deposited (get total-deposited status))
                (fee-rate (var-get service-fee-rate))  ;; 300 = 3%
                (service-fee (/ (* total-deposited fee-rate) u10000))
                (agent-fee (get agent-fee status))
                (total-fees (+ service-fee agent-fee))
                (host-amount (- total-deposited total-fees))
                (host (get host status))
                ;; Split SERVICE fees per community-fee-split (default 50/50)
                (service-split-rate (var-get community-fee-split))  ;; 5000 = 50%
                (service-community-share (/ (* service-fee service-split-rate) u10000))
                (service-platform-share (- service-fee service-community-share))
                ;; Split AGENT fees per agent-fee-community-split (default 0% to community)
                (agent-split-rate (var-get agent-fee-community-split))  ;; 0 = 0%
                (agent-community-share (/ (* agent-fee agent-split-rate) u10000))
                (agent-platform-share (- agent-fee agent-community-share))
                ;; Total shares
                (community-share (+ service-community-share agent-community-share))
                (platform-share (+ service-platform-share agent-platform-share))
                (platform-dest (var-get platform-treasury))
                (community-dest (get community-treasury status))
            )
                ;; Transfer host-amount to host
                (match (as-contract (contract-call? token transfer host-amount tx-sender host none))
                    host-success (begin
                        ;; Transfer platform share to Platform DAO treasury
                        (if (> platform-share u0)
                            (match (as-contract (contract-call? token transfer platform-share tx-sender platform-dest none))
                                platform-success (begin
                                    ;; Transfer community share to Community DAO treasury
                                    (if (> community-share u0)
                                        (match (as-contract (contract-call? token transfer community-share tx-sender community-dest none))
                                            community-success (begin
                                                (map-set escrow-status booking-id (merge status { released: true }))
                                                (print { 
                                                    event: "sip010-released", 
                                                    booking-id: booking-id,
                                                    token: token-contract,
                                                    host-amount: host-amount, 
                                                    service-fee: service-fee,
                                                    agent-fee: agent-fee,
                                                    total-fees: total-fees,
                                                    platform-share: platform-share,
                                                    community-share: community-share,
                                                    platform-treasury: platform-dest,
                                                    community-treasury: community-dest
                                                })
                                                (ok true)
                                            )
                                            community-error ERR-TRANSFER-FAILED
                                        )
                                        ;; No community share - mark as released
                                        (begin
                                            (map-set escrow-status booking-id (merge status { released: true }))
                                            (print { 
                                                event: "sip010-released", 
                                                booking-id: booking-id,
                                                token: token-contract,
                                                host-amount: host-amount, 
                                                service-fee: service-fee,
                                                agent-fee: agent-fee,
                                                total-fees: total-fees,
                                                platform-share: platform-share,
                                                community-share: u0,
                                                platform-treasury: platform-dest,
                                                community-treasury: community-dest
                                            })
                                            (ok true)
                                        )
                                    )
                                )
                                platform-error ERR-TRANSFER-FAILED
                            )
                            ;; No platform share (shouldn't happen but handle gracefully)
                            (begin
                                (map-set escrow-status booking-id (merge status { released: true }))
                                (print { 
                                    event: "sip010-released", 
                                    booking-id: booking-id,
                                    token: token-contract,
                                    host-amount: host-amount, 
                                    service-fee: service-fee,
                                    agent-fee: agent-fee,
                                    total-fees: total-fees,
                                    platform-share: u0,
                                    community-share: u0,
                                    platform-treasury: platform-dest,
                                    community-treasury: community-dest
                                })
                                (ok true)
                            )
                        )
                    )
                    host-error ERR-TRANSFER-FAILED
                )
            )
        )
    )
)

;; --- Refund Functions ---

;; @desc Refunds STX funds from escrow to the guest
(define-public (refund-stx (booking-id uint) (amount uint))
    (let ((status (unwrap! (map-get? escrow-status booking-id) ERR-BOOKING-NOT-FOUND))
          (sender tx-sender))
        (begin
            ;; Verify is STX payment
            (asserts! (get is-stx status) ERR-INVALID-TOKEN)
            ;; Verify sender is guest or host
            (asserts! (or (is-eq sender (get guest status)) (is-eq sender (get host status))) ERR-UNAUTHORIZED)
            ;; Verify funds are deposited
            (asserts! (get deposited status) ERR-INVALID-STATE)
            ;; Verify not already fully refunded
            (asserts! (not (get refunded status)) ERR-INVALID-STATE)
            ;; Validate amount
            (asserts! (> amount u0) ERR-INVALID-AMOUNT)
            (asserts! (<= amount (get total-deposited status)) ERR-INSUFFICIENT-FUNDS)
            
            (let ((guest (get guest status)))
                ;; Transfer amount to guest
                (match (as-contract (stx-transfer? amount tx-sender guest))
                    success (begin
                        ;; Mark as refunded if full refund
                        (if (is-eq amount (get total-deposited status))
                            (map-set escrow-status booking-id (merge status { refunded: true }))
                            (map-set escrow-status booking-id 
                                (merge status { total-deposited: (- (get total-deposited status) amount) }))
                        )
                        (print { event: "stx-refunded", booking-id: booking-id, amount: amount })
                        (ok true)
                    )
                    error ERR-TRANSFER-FAILED
                )
            )
        )
    )
)

;; @desc Refunds SIP-010 token funds from escrow to the guest
(define-public (refund-sip010 (booking-id uint) (amount uint) (token <sip-010-trait>))
    (let (
        (status (unwrap! (map-get? escrow-status booking-id) ERR-BOOKING-NOT-FOUND))
        (sender tx-sender)
        (token-contract (contract-of token))
    )
        (begin
            ;; Verify token matches booking
            (asserts! (is-eq token-contract (get token status)) ERR-INVALID-TOKEN)
            ;; Verify is NOT STX payment
            (asserts! (not (get is-stx status)) ERR-INVALID-TOKEN)
            ;; Verify sender is guest or host
            (asserts! (or (is-eq sender (get guest status)) (is-eq sender (get host status))) ERR-UNAUTHORIZED)
            ;; Verify funds are deposited
            (asserts! (get deposited status) ERR-INVALID-STATE)
            ;; Verify not already fully refunded
            (asserts! (not (get refunded status)) ERR-INVALID-STATE)
            ;; Validate amount
            (asserts! (> amount u0) ERR-INVALID-AMOUNT)
            (asserts! (<= amount (get total-deposited status)) ERR-INSUFFICIENT-FUNDS)
            
            (let ((guest (get guest status)))
                ;; Transfer amount to guest
                (match (as-contract (contract-call? token transfer amount tx-sender guest none))
                    success (begin
                        ;; Mark as refunded if full refund
                        (if (is-eq amount (get total-deposited status))
                            (map-set escrow-status booking-id (merge status { refunded: true }))
                            (map-set escrow-status booking-id 
                                (merge status { total-deposited: (- (get total-deposited status) amount) }))
                        )
                        (print { 
                            event: "sip010-refunded", 
                            booking-id: booking-id, 
                            token: token-contract,
                            amount: amount 
                        })
                        (ok true)
                    )
                    error ERR-TRANSFER-FAILED
                )
            )
        )
    )
)

;; --- Legacy Compatibility ---

;; @desc Legacy deposit function (STX only) - forwards to deposit-stx
(define-public (deposit
    (booking-id uint)
    (amount uint)
    (token principal)
    (guest principal)
    (host principal)
)
    (deposit-stx booking-id amount guest host u0)
)

;; @desc Legacy release function (STX only) - forwards to release-stx
(define-public (release (booking-id uint))
    (release-stx booking-id)
)

;; @desc Legacy refund function (STX only) - forwards to refund-stx
(define-public (refund (booking-id uint) (amount uint))
    (refund-stx booking-id amount)
)

;; --- Read-Only Functions ---

;; @desc Get escrow balance for a booking and token
(define-read-only (get-balance (booking-id uint) (token principal))
    (ok (default-to u0 (map-get? escrow-balances { booking-id: booking-id, token: token })))
)

;; @desc Get escrow status for a booking
(define-read-only (get-escrow-status (booking-id uint))
    (ok (default-to {
        deposited: false,
        released: false,
        refunded: false,
        total-deposited: u0,
        guest: tx-sender,
        host: tx-sender,
        token: STX-TOKEN,
        is-stx: true,
        usd-amount: u0,
        agent-fee: u0,
        agent-used: false,
        community-treasury: (var-get default-community-treasury)
    } (map-get? escrow-status booking-id)))
)

;; @desc Calculate service fee for an amount
(define-read-only (calculate-service-fee (amount uint))
    (let ((fee-rate (var-get service-fee-rate)))
        (ok (/ (* amount fee-rate) u10000))
    )
)

;; @desc Get current service fee rate
(define-read-only (get-service-fee-rate)
    (ok (var-get service-fee-rate))
)

;; @desc Get current agent fee rate
(define-read-only (get-agent-fee-rate)
    (ok (var-get agent-fee-rate))
)

;; @desc Get Platform DAO treasury address
(define-read-only (get-platform-treasury)
    (ok (var-get platform-treasury))
)

;; @desc Get default Community DAO treasury address
(define-read-only (get-default-community-treasury)
    (ok (var-get default-community-treasury))
)

;; @desc Get community fee split percentage for SERVICE fees (basis points)
(define-read-only (get-community-fee-split)
    (ok (var-get community-fee-split))
)

;; @desc Get community fee split percentage for AGENT fees (basis points)
(define-read-only (get-agent-fee-community-split)
    (ok (var-get agent-fee-community-split))
)

;; @desc Get agent fee for a specific booking
(define-read-only (get-booking-agent-fee (booking-id uint))
    (let ((status (map-get? escrow-status booking-id)))
        (match status
            s (ok { agent-fee: (get agent-fee s), agent-used: (get agent-used s) })
            (ok { agent-fee: u0, agent-used: false })
        )
    )
)

;; @desc Get agent usage stats for a booking
(define-read-only (get-agent-usage (booking-id uint))
    (ok (default-to {
        llm-calls: u0,
        auto-responses: u0,
        service-requests: u0,
        last-activity: u0
    } (map-get? booking-agent-usage booking-id)))
)

;; @desc Calculate total fees for a booking with separate DAO splits
;; Service fee: 3% (split per community-fee-split, default 50/50)
;; Agent fee: 1% (split per agent-fee-community-split, default 100% Platform)
(define-read-only (calculate-total-fees (booking-id uint))
    (let ((status (map-get? escrow-status booking-id)))
        (match status
            s (let (
                (total (get total-deposited s))
                (fee-rate (var-get service-fee-rate))  ;; 300 = 3%
                (service-fee (/ (* total fee-rate) u10000))
                (agent-fee (get agent-fee s))
                (total-fees (+ service-fee agent-fee))
                (host-amount (- total total-fees))
                ;; Calculate SERVICE fee split
                (service-split-rate (var-get community-fee-split))  ;; 5000 = 50%
                (service-community-share (/ (* service-fee service-split-rate) u10000))
                (service-platform-share (- service-fee service-community-share))
                ;; Calculate AGENT fee split (default 100% to Platform)
                (agent-split-rate (var-get agent-fee-community-split))  ;; 0 = 0%
                (agent-community-share (/ (* agent-fee agent-split-rate) u10000))
                (agent-platform-share (- agent-fee agent-community-share))
                ;; Total shares
                (community-share (+ service-community-share agent-community-share))
                (platform-share (+ service-platform-share agent-platform-share))
            )
                (ok {
                    total-deposited: total,
                    service-fee: service-fee,
                    agent-fee: agent-fee,
                    total-fees: total-fees,
                    host-payout: host-amount,
                    platform-share: platform-share,
                    community-share: community-share,
                    service-platform-share: service-platform-share,
                    service-community-share: service-community-share,
                    agent-platform-share: agent-platform-share,
                    agent-community-share: agent-community-share,
                    fee-rate-bps: fee-rate,
                    agent-fee-rate-bps: (var-get agent-fee-rate),
                    service-community-split-bps: service-split-rate,
                    agent-community-split-bps: agent-split-rate
                })
            )
            (err ERR-BOOKING-NOT-FOUND)
        )
    )
)

;; @desc Preview payout for a booking (before release)
(define-read-only (preview-payout (booking-id uint))
    (calculate-total-fees booking-id)
)

;; @desc Get fee summary - useful for displaying to users
(define-read-only (get-fee-summary)
    (ok {
        service-fee-rate: (var-get service-fee-rate),                     ;; 300 = 3% total
        agent-fee-rate: (var-get agent-fee-rate),                         ;; 100 = 1% additional
        service-community-split: (var-get community-fee-split),           ;; 5000 = 50% (service fees)
        agent-community-split: (var-get agent-fee-community-split),       ;; 0 = 0% (agent fees go to Platform)
        platform-treasury: (var-get platform-treasury),
        default-community-treasury: (var-get default-community-treasury),
        total-fee-no-agent: (var-get service-fee-rate),                   ;; 3%
        total-fee-with-agent: (+ (var-get service-fee-rate) (var-get agent-fee-rate))  ;; 4%
    })
)

;; @desc Check if a token is supported
(define-read-only (is-token-supported (token-contract principal))
    (match (map-get? supported-tokens token-contract)
        token-info (ok (get is-active token-info))
        (ok false)
    )
)

;; @desc Get token info
(define-read-only (get-token-info (token-contract principal))
    (ok (map-get? supported-tokens token-contract))
)

;; @desc Get admin address
(define-read-only (get-admin)
    (ok (var-get admin))
)

;; @desc Check if STX token constant
(define-read-only (get-stx-token)
    (ok STX-TOKEN)
)
