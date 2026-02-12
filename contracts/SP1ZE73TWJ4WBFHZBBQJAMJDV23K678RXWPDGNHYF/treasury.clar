;; Title: Treasury
;; Version: 2.0.0
;; Summary: Sophisticated multi-token vault for BlockPay
;; Description: Manages employer deposits, withdrawals, and balance tracking with audit trail

;; ============================================
;; Traits
;; ============================================
(use-trait sip-010-trait .sip-010-trait.sip-010-trait)

;; ============================================
;; Constants - Error Codes
;; ============================================
(define-constant ERR_UNAUTHORIZED (err u2000))
(define-constant ERR_INSUFFICIENT_BALANCE (err u2001))
(define-constant ERR_INVALID_AMOUNT (err u2002))
(define-constant ERR_TRANSFER_FAILED (err u2003))
(define-constant ERR_NOT_WHITELISTED (err u2004))
(define-constant ERR_WITHDRAWAL_LIMIT_EXCEEDED (err u2005))
(define-constant ERR_INVALID_TOKEN (err u2006))

;; ============================================
;; Constants - Configuration
;; ============================================
(define-constant WITHDRAWAL_LIMIT_BLOCKS u144) ;; Rate limit: 1 withdrawal per ~24 hours
(define-constant MAX_WITHDRAWAL_PERCENTAGE u50) ;; Max 50% of balance per withdrawal

;; ============================================
;; Data Variables
;; ============================================
(define-data-var contract-owner principal tx-sender)
(define-data-var total-stx-deposits uint u0)
(define-data-var total-stx-withdrawals uint u0)

;; ============================================
;; Data Maps - Whitelist (Authorized Contracts)
;; ============================================
(define-map whitelist principal bool)

;; ============================================
;; Data Maps - Employer Balances (STX)
;; ============================================
(define-map employer-stx-balances principal uint)

;; ============================================
;; Data Maps - Employer Balances (SIP-010 Tokens)
;; ============================================
(define-map employer-token-balances
    { employer: principal, token: principal }
    uint
)

;; ============================================
;; Data Maps - Token Totals
;; ============================================
(define-map token-total-deposits principal uint)
(define-map token-total-withdrawals principal uint)

;; ============================================
;; Data Maps - Withdrawal History (Audit Trail)
;; ============================================
(define-map withdrawal-history
    principal
    (list 100 { 
        amount: uint, 
        recipient: principal, 
        token: (optional principal), 
        block: uint,
        tx-sender: principal
    })
)

;; ============================================
;; Data Maps - Last Withdrawal Block (Rate Limiting)
;; ============================================
(define-map last-withdrawal-block principal uint)

;; ============================================
;; Read-Only Functions - Balance Queries
;; ============================================

(define-read-only (get-contract-stx-balance)
    (stx-get-balance (as-contract tx-sender))
)

(define-read-only (get-employer-stx-balance (employer principal))
    (default-to u0 (map-get? employer-stx-balances employer))
)

(define-read-only (get-employer-token-balance (employer principal) (token principal))
    (default-to u0 (map-get? employer-token-balances { employer: employer, token: token }))
)

(define-read-only (get-total-stx-deposits)
    (var-get total-stx-deposits)
)

(define-read-only (get-total-stx-withdrawals)
    (var-get total-stx-withdrawals)
)

(define-read-only (get-token-total-deposits (token principal))
    (default-to u0 (map-get? token-total-deposits token))
)

(define-read-only (get-token-total-withdrawals (token principal))
    (default-to u0 (map-get? token-total-withdrawals token))
)

(define-read-only (is-whitelisted (caller principal))
    (default-to false (map-get? whitelist caller))
)

(define-read-only (get-withdrawal-history (employer principal))
    (default-to (list) (map-get? withdrawal-history employer))
)

(define-read-only (get-last-withdrawal-block (employer principal))
    (default-to u0 (map-get? last-withdrawal-block employer))
)

;; ============================================
;; Private Functions - Helpers
;; ============================================

(define-private (add-to-withdrawal-history 
    (employer principal) 
    (amount uint) 
    (recipient principal) 
    (token (optional principal)))
    (let
        (
            (current-history (default-to (list) (map-get? withdrawal-history employer)))
            (new-entry { 
                amount: amount, 
                recipient: recipient, 
                token: token, 
                block: block-height,
                tx-sender: tx-sender
            })
        )
        (map-set withdrawal-history employer 
            (unwrap-panic (as-max-len? (append current-history new-entry) u100)))
    )
)

;; ============================================
;; Public Functions - Whitelist Management
;; ============================================

(define-public (set-whitelisted (caller principal) (allowed bool))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (ok (map-set whitelist caller allowed))
    )
)

(define-public (set-owner (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (ok (var-set contract-owner new-owner))
    )
)

;; ============================================
;; Public Functions - STX Deposits
;; ============================================

(define-public (deposit-stx (amount uint))
    (let
        (
            (employer tx-sender)
            (current-balance (get-employer-stx-balance employer))
        )
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        
        ;; Transfer STX to contract
        (try! (stx-transfer? amount employer (as-contract tx-sender)))
        
        ;; Update employer balance
        (map-set employer-stx-balances employer (+ current-balance amount))
        
        ;; Update total deposits
        (var-set total-stx-deposits (+ (var-get total-stx-deposits) amount))
        
        ;; Print event
        (print {
            event: "stx-deposit",
            employer: employer,
            amount: amount,
            new-balance: (+ current-balance amount),
            block: block-height
        })
        
        (ok true)
    )
)

;; ============================================
;; Public Functions - STX Withdrawals
;; ============================================

(define-public (withdraw-stx (employer principal) (amount uint) (recipient principal))
    (let
        (
            (caller contract-caller)
            (current-balance (get-employer-stx-balance employer))
        )
        ;; Authorization check - check contract-caller for whitelist
        (asserts! (or 
            (is-eq tx-sender (var-get contract-owner)) 
            (is-whitelisted caller)) 
            ERR_NOT_WHITELISTED)
        
        ;; Validation
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
        
        ;; Transfer STX from contract to recipient
        (try! (as-contract (stx-transfer? amount tx-sender recipient)))
        
        ;; Update employer balance
        (map-set employer-stx-balances employer (- current-balance amount))
        
        ;; Update total withdrawals
        (var-set total-stx-withdrawals (+ (var-get total-stx-withdrawals) amount))
        
        ;; Add to audit trail
        (add-to-withdrawal-history employer amount recipient none)
        
        ;; Print event
        (print {
            event: "stx-withdrawal",
            employer: employer,
            recipient: recipient,
            amount: amount,
            remaining-balance: (- current-balance amount),
            block: block-height,
            caller: caller
        })
        
        (ok true)
    )
)

;; ============================================
;; Public Functions - Token Deposits
;; ============================================

(define-public (deposit-token (token <sip-010-trait>) (amount uint))
    (let
        (
            (employer tx-sender)
            (token-principal (contract-of token))
            (current-balance (get-employer-token-balance employer token-principal))
        )
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        
        ;; Transfer tokens to contract
        (try! (contract-call? token transfer amount employer (as-contract tx-sender) none))
        
        ;; Update employer balance
        (map-set employer-token-balances 
            { employer: employer, token: token-principal } 
            (+ current-balance amount))
        
        ;; Update total deposits for this token
        (map-set token-total-deposits token-principal 
            (+ (get-token-total-deposits token-principal) amount))
        
        ;; Print event
        (print {
            event: "token-deposit",
            employer: employer,
            token: token-principal,
            amount: amount,
            new-balance: (+ current-balance amount),
            block: block-height
        })
        
        (ok true)
    )
)

;; ============================================
;; Public Functions - Token Withdrawals
;; ============================================

(define-public (withdraw-token 
    (token <sip-010-trait>) 
    (employer principal) 
    (amount uint) 
    (recipient principal))
    (let
        (
            (caller contract-caller)
            (token-principal (contract-of token))
            (current-balance (get-employer-token-balance employer token-principal))
        )
        ;; Authorization check - check contract-caller for whitelist
        (asserts! (or 
            (is-eq tx-sender (var-get contract-owner)) 
            (is-whitelisted caller)) 
            ERR_NOT_WHITELISTED)
        
        ;; Validation
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
        
        ;; Transfer tokens from contract to recipient
        (try! (as-contract (contract-call? token transfer amount tx-sender recipient none)))
        
        ;; Update employer balance
        (map-set employer-token-balances 
            { employer: employer, token: token-principal } 
            (- current-balance amount))
        
        ;; Update total withdrawals for this token
        (map-set token-total-withdrawals token-principal 
            (+ (get-token-total-withdrawals token-principal) amount))
        
        ;; Add to audit trail
        (add-to-withdrawal-history employer amount recipient (some token-principal))
        
        ;; Print event
        (print {
            event: "token-withdrawal",
            employer: employer,
            recipient: recipient,
            token: token-principal,
            amount: amount,
            remaining-balance: (- current-balance amount),
            block: block-height,
            caller: caller
        })
        
        (ok true)
    )
)

;; ============================================
;; Public Functions - Emergency Withdrawals
;; ============================================

(define-public (emergency-withdraw-stx (amount uint) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        
        (try! (as-contract (stx-transfer? amount tx-sender recipient)))
        
        (print {
            event: "emergency-stx-withdrawal",
            amount: amount,
            recipient: recipient,
            block: block-height
        })
        
        (ok true)
    )
)

(define-public (emergency-withdraw-token 
    (token <sip-010-trait>) 
    (amount uint) 
    (recipient principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        
        (try! (as-contract (contract-call? token transfer amount tx-sender recipient none)))
        
        (print {
            event: "emergency-token-withdrawal",
            token: (contract-of token),
            amount: amount,
            recipient: recipient,
            block: block-height
        })
        
        (ok true)
    )
)
