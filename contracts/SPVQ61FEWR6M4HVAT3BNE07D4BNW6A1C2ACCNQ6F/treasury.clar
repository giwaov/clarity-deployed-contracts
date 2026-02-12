;; DAO Treasury Contract
;; Manages funds and executes transfers authorized by governance

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u300))
(define-constant err-not-authorized (err u301))
(define-constant err-insufficient-balance (err u302))
(define-constant err-invalid-amount (err u303))
(define-constant err-proposal-not-executed (err u304))
(define-constant err-transfer-failed (err u305))

;; Data variables
(define-data-var proposal-system-contract principal .proposal-system)
(define-data-var total-deposited uint u0)
(define-data-var total-withdrawn uint u0)
(define-data-var treasury-balance uint u0)

;; Data maps
(define-map authorized-proposals uint bool)
(define-map spending-history 
    uint 
    { 
        recipient: principal, 
        amount: uint, 
        timestamp: uint,
        proposal-id: uint,
        description: (string-utf8 200)
    }
)
(define-data-var spending-count uint u0)

;; Deposit funds into treasury
(define-public (deposit-funds (amount uint))
    (begin
        (asserts! (> amount u0) err-invalid-amount)
        (var-set total-deposited (+ (var-get total-deposited) amount))
        (var-set treasury-balance (+ (var-get treasury-balance) amount))
        (print { 
            event: "funds-deposited", 
            depositor: tx-sender, 
            amount: amount,
            new-balance: (var-get treasury-balance)
        })
        (ok true)
    )
)

;; Withdraw funds (only through governance)
(define-public (withdraw-funds (amount uint) (recipient principal) (proposal-id uint) (description (string-utf8 200)))
    (let (
        (spending-id (+ (var-get spending-count) u1))
    )
        (asserts! (> amount u0) err-invalid-amount)
        (asserts! (is-authorized-proposal proposal-id) err-not-authorized)
        (asserts! (>= (var-get treasury-balance) amount) err-insufficient-balance)
        
        (var-set total-withdrawn (+ (var-get total-withdrawn) amount))
        (var-set treasury-balance (- (var-get treasury-balance) amount))
        (map-set spending-history spending-id {
            recipient: recipient,
            amount: amount,
            timestamp: stacks-block-height,
            proposal-id: proposal-id,
            description: description
        })
        (var-set spending-count spending-id)
        
        (print { 
            event: "funds-withdrawn", 
            recipient: recipient, 
            amount: amount,
            proposal-id: proposal-id,
            spending-id: spending-id
        })
        (ok spending-id)
    )
)

;; Execute transfer approved by governance
(define-public (execute-transfer (recipient principal) (amount uint) (proposal-id uint) (description (string-utf8 200)))
    (begin
        ;; Verify proposal is executed in the proposal system
        (asserts! (is-proposal-executed proposal-id) err-proposal-not-executed)
        
        ;; Authorize and execute withdrawal
        (map-set authorized-proposals proposal-id true)
        (withdraw-funds amount recipient proposal-id description)
    )
)

;; Authorize a proposal (only proposal system can call)
(define-public (authorize-proposal (proposal-id uint))
    (begin
        (asserts! (is-eq contract-caller (var-get proposal-system-contract)) err-not-authorized)
        (map-set authorized-proposals proposal-id true)
        (print { event: "proposal-authorized", proposal-id: proposal-id })
        (ok true)
    )
)

;; Emergency withdrawal (only owner, for security)
(define-public (emergency-withdraw (amount uint) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> amount u0) err-invalid-amount)
        (asserts! (>= (var-get treasury-balance) amount) err-insufficient-balance)
        
        (var-set total-withdrawn (+ (var-get total-withdrawn) amount))
        (var-set treasury-balance (- (var-get treasury-balance) amount))
        
        (print { 
            event: "emergency-withdrawal", 
            recipient: recipient, 
            amount: amount 
        })
        (ok true)
    )
)

;; Update proposal system contract (only owner)
(define-public (set-proposal-system (new-contract principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set proposal-system-contract new-contract)
        (print { event: "proposal-system-updated", new-contract: new-contract })
        (ok true)
    )
)

;; Read-only functions

(define-read-only (get-balance)
    (var-get treasury-balance)
)

(define-read-only (get-total-deposited)
    (ok (var-get total-deposited))
)

(define-read-only (get-total-withdrawn)
    (ok (var-get total-withdrawn))
)

(define-read-only (is-authorized-proposal (proposal-id uint))
    (default-to false (map-get? authorized-proposals proposal-id))
)

(define-read-only (get-spending-history (spending-id uint))
    (ok (map-get? spending-history spending-id))
)

(define-read-only (get-spending-count)
    (ok (var-get spending-count))
)

(define-read-only (get-proposal-system-contract)
    (ok (var-get proposal-system-contract))
)

;; Helper function to check if proposal is executed
(define-private (is-proposal-executed (proposal-id uint))
    ;; This would interact with proposal-system contract
    ;; For now, we'll use a simplified check
    (is-authorized-proposal proposal-id)
)

;; Treasury statistics
(define-read-only (get-treasury-stats)
    (ok {
        current-balance: (var-get treasury-balance),
        total-deposited: (var-get total-deposited),
        total-withdrawn: (var-get total-withdrawn),
        spending-count: (var-get spending-count)
    })
)
