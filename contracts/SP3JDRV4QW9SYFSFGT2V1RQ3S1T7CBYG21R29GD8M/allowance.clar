;; STX Allowance Contract
;; Allows users to approve others to spend STX on their behalf

;; Constants
(define-constant err-insufficient-allowance (err u100))
(define-constant err-insufficient-balance (err u101))
(define-constant err-transfer-failed (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-self-approval (err u104))
(define-constant err-self-transfer (err u105))

;; Data maps
;; Maps owner -> spender -> amount
(define-map allowances 
    {owner: principal, spender: principal}
    {amount: uint}
)

;; Events (using print for event-like functionality)
(define-private (log-approval (owner principal) (spender principal) (amount uint))
    (print {
        event: "approval",
        owner: owner,
        spender: spender,
        amount: amount
    })
)

(define-private (log-transfer (from principal) (to principal) (amount uint))
    (print {
        event: "transfer",
        from: from,
        to: to,
        amount: amount
    })
)

;; Read-only functions

;; Get the allowance amount
(define-read-only (get-allowance (owner principal) (spender principal))
    (ok (get amount (default-to {amount: u0} 
        (map-get? allowances {owner: owner, spender: spender}))))
)

;; Get STX balance
(define-read-only (get-balance (wallet principal))
    (ok (stx-get-balance wallet))
)

;; Check if spender can spend a specific amount
(define-read-only (can-spend (owner principal) (spender principal) (amount uint))
    (let
        (
            (current-allowance (get amount (default-to {amount: u0} 
                (map-get? allowances {owner: owner, spender: spender}))))
        )
        (ok (>= current-allowance amount))
    )
)

;; Public functions

;; Approve a spender to spend tokens on behalf of the caller
(define-public (approve (spender principal) (amount uint))
    (begin
        (asserts! (not (is-eq tx-sender spender)) err-self-approval)
        (map-set allowances 
            {owner: tx-sender, spender: spender}
            {amount: amount}
        )
        (log-approval tx-sender spender amount)
        (ok true)
    )
)

;; Increase allowance
(define-public (increase-allowance (spender principal) (increment uint))
    (let
        (
            (current-allowance (get amount (default-to {amount: u0} 
                (map-get? allowances {owner: tx-sender, spender: spender}))))
            (new-allowance (+ current-allowance increment))
        )
        (begin
            (asserts! (not (is-eq tx-sender spender)) err-self-approval)
            (map-set allowances 
                {owner: tx-sender, spender: spender}
                {amount: new-allowance}
            )
            (log-approval tx-sender spender new-allowance)
            (ok new-allowance)
        )
    )
)

;; Decrease allowance
(define-public (decrease-allowance (spender principal) (decrement uint))
    (let
        (
            (current-allowance (get amount (default-to {amount: u0} 
                (map-get? allowances {owner: tx-sender, spender: spender}))))
            (new-allowance (if (>= current-allowance decrement)
                (- current-allowance decrement)
                u0))
        )
        (begin
            (asserts! (not (is-eq tx-sender spender)) err-self-approval)
            (map-set allowances 
                {owner: tx-sender, spender: spender}
                {amount: new-allowance}
            )
            (log-approval tx-sender spender new-allowance)
            (ok new-allowance)
        )
    )
)

;; Transfer tokens directly from sender
(define-public (transfer (amount uint) (recipient principal))
    (begin
        (asserts! (> amount u0) err-invalid-amount)
        (asserts! (not (is-eq tx-sender recipient)) err-self-transfer)
        (asserts! (>= (stx-get-balance tx-sender) amount) err-insufficient-balance)
        
        (match (stx-transfer? amount tx-sender recipient)
            success (begin
                (log-transfer tx-sender recipient amount)
                (ok true)
            )
            error err-transfer-failed
        )
    )
)

;; Transfer tokens from another account using allowance
(define-public (transfer-from (owner principal) (recipient principal) (amount uint))
    (let
        (
            (current-allowance (get amount (default-to {amount: u0} 
                (map-get? allowances {owner: owner, spender: tx-sender}))))
        )
        (begin
            ;; Validation checks
            (asserts! (> amount u0) err-invalid-amount)
            (asserts! (not (is-eq owner recipient)) err-self-transfer)
            (asserts! (>= current-allowance amount) err-insufficient-allowance)
            (asserts! (>= (stx-get-balance owner) amount) err-insufficient-balance)
            
            ;; Execute transfer
            (match (as-contract (stx-transfer? amount owner recipient))
                success (begin
                    ;; Decrease allowance
                    (map-set allowances 
                        {owner: owner, spender: tx-sender}
                        {amount: (- current-allowance amount)}
                    )
                    (log-transfer owner recipient amount)
                    (ok true)
                )
                error err-transfer-failed
            )
        )
    )
)

;; Revoke all allowance for a spender
(define-public (revoke-allowance (spender principal))
    (begin
        (map-delete allowances {owner: tx-sender, spender: spender})
        (log-approval tx-sender spender u0)
        (ok true)
    )
)