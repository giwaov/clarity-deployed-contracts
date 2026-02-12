;; TokenForge - Enhanced Trading Contract
;; A comprehensive token trading platform with advanced features

;; ============================================================
;; CONSTANTS & ERRORS
;; ============================================================
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_INSUFFICIENT_BALANCE (err u1))
(define-constant ERR_INVALID_AMOUNT (err u2))
(define-constant ERR_UNAUTHORIZED (err u3))
(define-constant ERR_TRADING_PAUSED (err u4))
(define-constant ERR_TRANSFER_FAILED (err u5))
(define-constant ERR_INVALID_RECIPIENT (err u6))
(define-constant ERR_PRICE_TOO_LOW (err u7))

;; ============================================================
;; DATA VARIABLES
;; ============================================================
(define-data-var total-supply uint u0)
(define-data-var trading-paused bool false)
(define-data-var token-price uint u100) ;; Price per token in microSTX
(define-data-var minimum-trade uint u1) ;; Minimum trade amount
(define-data-var maximum-trade uint u1000000) ;; Maximum trade amount
(define-data-var total-transactions uint u0)

;; ============================================================
;; DATA MAPS
;; ============================================================

;; Store user balances
(define-map balances 
    principal 
    uint
)

;; Track user transaction history count
(define-map user-transaction-count
    principal
    uint
)

;; Store transaction details
(define-map transactions
    uint ;; transaction-id
    {
        user: principal,
        action: (string-ascii 10),
        amount: uint,
        timestamp: uint,
        price: uint
    }
)

;; Allowances for transfers (like ERC20 approve/transferFrom)
(define-map allowances
    {owner: principal, spender: principal}
    uint
)

;; Track locked tokens (for future staking/vesting features)
(define-map locked-balances
    principal
    {
        amount: uint,
        unlock-height: uint
    }
)

;; Whitelist for special privileges
(define-map whitelist
    principal
    bool
)

;; ============================================================
;; PRIVATE FUNCTIONS
;; ============================================================

(define-private (record-transaction (action (string-ascii 10)) (amount uint))
    (let (
          (tx-id (var-get total-transactions))
          (sender tx-sender)
          (current-count (default-to u0 (map-get? user-transaction-count sender)))
         )
        (begin
            ;; Store transaction details
            (map-set transactions tx-id {
                user: sender,
                action: action,
                amount: amount,
                timestamp: stacks-block-height,
                price: (var-get token-price)
            })
            
            ;; Update user transaction count
            (map-set user-transaction-count sender (+ current-count u1))
            
            ;; Increment total transactions
            (var-set total-transactions (+ tx-id u1))
            
            tx-id
        )
    )
)

;; ============================================================
;; PUBLIC FUNCTIONS - TRADING
;; ============================================================

;; Buy tokens with enhanced validation
(define-public (buy (amount uint))
    (let (
          (sender tx-sender)
          (current-balance (default-to u0 (map-get? balances sender)))
          (min-trade (var-get minimum-trade))
          (max-trade (var-get maximum-trade))
         )
        (begin
            ;; Validations
            (asserts! (not (var-get trading-paused)) ERR_TRADING_PAUSED)
            (asserts! (> amount u0) ERR_INVALID_AMOUNT)
            (asserts! (>= amount min-trade) ERR_INVALID_AMOUNT)
            (asserts! (<= amount max-trade) ERR_INVALID_AMOUNT)
            
            ;; Update user balance
            (map-set balances sender (+ current-balance amount))
            
            ;; Update total supply
            (var-set total-supply (+ (var-get total-supply) amount))
            
            ;; Record transaction
            (record-transaction "buy" amount)
            
            (ok { 
                action: "buy", 
                amount: amount, 
                new-balance: (+ current-balance amount),
                price: (var-get token-price)
            })
        )
    )
)

;; Sell tokens with enhanced validation
(define-public (sell (amount uint))
    (let (
          (sender tx-sender)
          (current-balance (default-to u0 (map-get? balances sender)))
          (min-trade (var-get minimum-trade))
         )
        (begin
            ;; Validations
            (asserts! (not (var-get trading-paused)) ERR_TRADING_PAUSED)
            (asserts! (> amount u0) ERR_INVALID_AMOUNT)
            (asserts! (>= amount min-trade) ERR_INVALID_AMOUNT)
            (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
            
            ;; Update user balance
            (map-set balances sender (- current-balance amount))
            
            ;; Update total supply
            (var-set total-supply (- (var-get total-supply) amount))
            
            ;; Record transaction
            (record-transaction "sell" amount)
            
            (ok { 
                action: "sell", 
                amount: amount, 
                new-balance: (- current-balance amount),
                price: (var-get token-price)
            })
        )
    )
)

;; ============================================================
;; PUBLIC FUNCTIONS - TRANSFERS
;; ============================================================

;; Transfer tokens to another user
(define-public (transfer (amount uint) (recipient principal))
    (let (
          (sender tx-sender)
          (sender-balance (default-to u0 (map-get? balances sender)))
          (recipient-balance (default-to u0 (map-get? balances recipient)))
         )
        (begin
            ;; Validations
            (asserts! (not (is-eq sender recipient)) ERR_INVALID_RECIPIENT)
            (asserts! (> amount u0) ERR_INVALID_AMOUNT)
            (asserts! (>= sender-balance amount) ERR_INSUFFICIENT_BALANCE)
            
            ;; Update balances
            (map-set balances sender (- sender-balance amount))
            (map-set balances recipient (+ recipient-balance amount))
            
            ;; Record transaction
            (record-transaction "transfer" amount)
            
            (ok { 
                action: "transfer",
                from: sender,
                to: recipient,
                amount: amount
            })
        )
    )
)

;; Approve spender to use tokens
(define-public (approve (spender principal) (amount uint))
    (begin
        (asserts! (not (is-eq tx-sender spender)) ERR_INVALID_RECIPIENT)
        (map-set allowances {owner: tx-sender, spender: spender} amount)
        (ok { 
            owner: tx-sender, 
            spender: spender, 
            amount: amount 
        })
    )
)

;; Transfer tokens on behalf of owner (requires approval)
(define-public (transfer-from (owner principal) (recipient principal) (amount uint))
    (let (
          (allowance (default-to u0 (map-get? allowances {owner: owner, spender: tx-sender})))
          (owner-balance (default-to u0 (map-get? balances owner)))
          (recipient-balance (default-to u0 (map-get? balances recipient)))
         )
        (begin
            ;; Validations
            (asserts! (not (is-eq owner recipient)) ERR_INVALID_RECIPIENT)
            (asserts! (>= allowance amount) ERR_UNAUTHORIZED)
            (asserts! (>= owner-balance amount) ERR_INSUFFICIENT_BALANCE)
            
            ;; Update balances
            (map-set balances owner (- owner-balance amount))
            (map-set balances recipient (+ recipient-balance amount))
            
            ;; Update allowance
            (map-set allowances {owner: owner, spender: tx-sender} (- allowance amount))
            
            (ok { 
                action: "transfer-from",
                from: owner,
                to: recipient,
                amount: amount
            })
        )
    )
)

;; ============================================================
;; PUBLIC FUNCTIONS - ADMIN
;; ============================================================

;; Pause/unpause trading (owner only)
(define-public (set-trading-paused (paused bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set trading-paused paused)
        (ok { trading-paused: paused })
    )
)

;; Update token price (owner only)
(define-public (set-token-price (new-price uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (> new-price u0) ERR_PRICE_TOO_LOW)
        (var-set token-price new-price)
        (ok { new-price: new-price })
    )
)

;; Set trade limits (owner only)
(define-public (set-trade-limits (min uint) (max uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (< min max) ERR_INVALID_AMOUNT)
        (var-set minimum-trade min)
        (var-set maximum-trade max)
        (ok { minimum: min, maximum: max })
    )
)

;; Add to whitelist (owner only)
(define-public (add-to-whitelist (user principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set whitelist user true)
        (ok { user: user, whitelisted: true })
    )
)

;; ============================================================
;; READ-ONLY FUNCTIONS
;; ============================================================

;; Get user balance
(define-read-only (get-balance (user principal))
    (ok (default-to u0 (map-get? balances user)))
)

;; Get total supply
(define-read-only (get-total-supply)
    (ok (var-get total-supply))
)

;; Get current token price
(define-read-only (get-token-price)
    (ok (var-get token-price))
)

;; Check if trading is paused
(define-read-only (is-trading-paused)
    (ok (var-get trading-paused))
)

;; Get trade limits
(define-read-only (get-trade-limits)
    (ok {
        minimum: (var-get minimum-trade),
        maximum: (var-get maximum-trade)
    })
)

;; Get user transaction count
(define-read-only (get-user-transaction-count (user principal))
    (ok (default-to u0 (map-get? user-transaction-count user)))
)

;; Get transaction details
(define-read-only (get-transaction (tx-id uint))
    (ok (map-get? transactions tx-id))
)

;; Get total transactions
(define-read-only (get-total-transactions)
    (ok (var-get total-transactions))
)

;; Get allowance
(define-read-only (get-allowance (owner principal) (spender principal))
    (ok (default-to u0 (map-get? allowances {owner: owner, spender: spender})))
)

;; Check if user is whitelisted
(define-read-only (is-whitelisted (user principal))
    (ok (default-to false (map-get? whitelist user)))
)

;; Get user's locked balance
(define-read-only (get-locked-balance (user principal))
    (ok (map-get? locked-balances user))
)

;; Get contract info
(define-read-only (get-contract-info)
    (ok {
        total-supply: (var-get total-supply),
        token-price: (var-get token-price),
        trading-paused: (var-get trading-paused),
        total-transactions: (var-get total-transactions),
        contract-owner: CONTRACT_OWNER
    })
)