;; title: Bitdap Token
;; version: 1.0.0
;; summary: ERC20-like fungible token for the Bitdap ecosystem
;; description: >
;;   Bitdap Token is a fungible token that implements ERC20-like functionality
;;   on the Stacks blockchain using Clarity. It provides standard token operations
;;   including transfers, approvals, minting, and burning.

;; SIP-010 trait for fungible tokens
(use-trait sip-010-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)
(impl-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant TOKEN-NAME "Bitdap Token")
(define-constant TOKEN-SYMBOL "BITDAP")
(define-constant TOKEN-DECIMALS u6)
(define-constant TOKEN-MAX-SUPPLY u1000000000000) ;; 1 million tokens with 6 decimals

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-INSUFFICIENT-BALANCE (err u402))
(define-constant ERR-INSUFFICIENT-ALLOWANCE (err u403))
(define-constant ERR-INVALID-AMOUNT (err u404))
(define-constant ERR-SELF-TRANSFER (err u405))
(define-constant ERR-MAX-SUPPLY-EXCEEDED (err u406))
(define-constant ERR-INVALID-RECIPIENT (err u407))
(define-constant ERR-CONTRACT-PAUSED (err u408))

;; Data variables
(define-data-var total-supply uint u0)
(define-data-var contract-owner principal CONTRACT-OWNER)
(define-data-var token-paused bool false)
(define-data-var token-uri (optional (string-utf8 256)) none)

;; Data maps
;; Principal -> balance
(define-map balances principal uint)

;; Owner -> Spender -> allowance
(define-map allowances { owner: principal, spender: principal } uint)

;; Private functions

;; Check if amount is valid (greater than 0)
(define-private (is-valid-amount (amount uint))
    (> amount u0)
)

;; Check if contract is not paused
(define-private (is-not-paused)
    (not (var-get token-paused))
)

;; Get balance for a principal (returns 0 if not found)
(define-private (get-balance-or-default (account principal))
    (default-to u0 (map-get? balances account))
)

;; Get allowance for owner-spender pair (returns 0 if not found)
(define-private (get-allowance-or-default (owner principal) (spender principal))
    (default-to u0 (map-get? allowances { owner: owner, spender: spender }))
)

;; Set balance for a principal
(define-private (set-balance (account principal) (amount uint))
    (if (is-eq amount u0)
        (map-delete balances account)
        (map-set balances account amount)
    )
)

;; Set allowance for owner-spender pair
(define-private (set-allowance (owner principal) (spender principal) (amount uint))
    (if (is-eq amount u0)
        (map-delete allowances { owner: owner, spender: spender })
        (map-set allowances { owner: owner, spender: spender } amount)
    )
)

;; Public functions

;; SIP-010 required functions

;; Transfer tokens from sender to recipient
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        ;; Check if contract is not paused
        (asserts! (is-not-paused) ERR-CONTRACT-PAUSED)
        ;; Validate inputs
        (asserts! (is-valid-amount amount) ERR-INVALID-AMOUNT)
        (asserts! (not (is-eq sender recipient)) ERR-SELF-TRANSFER)
        (asserts! (is-eq sender tx-sender) ERR-UNAUTHORIZED)
        
        (let (
            (sender-balance (get-balance-or-default sender))
        )
            ;; Check sufficient balance
            (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
            
            ;; Update balances
            (set-balance sender (- sender-balance amount))
            (set-balance recipient (+ (get-balance-or-default recipient) amount))
            
            ;; Print transfer event
            (print {
                action: "transfer",
                sender: sender,
                recipient: recipient,
                amount: amount,
                memo: memo
            })
            
            (ok true)
        )
    )
)

;; Get token name
(define-read-only (get-name)
    (ok TOKEN-NAME)
)

;; Get token symbol
(define-read-only (get-symbol)
    (ok TOKEN-SYMBOL)
)

;; Get token decimals
(define-read-only (get-decimals)
    (ok TOKEN-DECIMALS)
)

;; Get balance of an account
(define-read-only (get-balance (account principal))
    (ok (get-balance-or-default account))
)

;; Get total supply
(define-read-only (get-total-supply)
    (ok (var-get total-supply))
)

;; Get token URI
(define-read-only (get-token-uri)
    (ok (var-get token-uri))
)

;; Additional ERC20-like functions

;; Approve spender to spend tokens on behalf of owner
(define-public (approve (spender principal) (amount uint))
    (begin
        ;; Check if contract is not paused
        (asserts! (is-not-paused) ERR-CONTRACT-PAUSED)
        ;; Validate inputs
        (asserts! (not (is-eq spender tx-sender)) ERR-INVALID-RECIPIENT)
        
        ;; Set allowance (amount is validated by being uint type)
        (set-allowance tx-sender spender amount)
        
        ;; Print approval event
        (print {
            action: "approve",
            owner: tx-sender,
            spender: spender,
            amount: amount
        })
        
        (ok true)
    )
)

;; Get allowance for owner-spender pair
(define-read-only (get-allowance (owner principal) (spender principal))
    (ok (get-allowance-or-default owner spender))
)

;; Transfer tokens from owner to recipient using allowance
(define-public (transfer-from (owner principal) (recipient principal) (amount uint) (memo (optional (buff 34))))
    (begin
        ;; Check if contract is not paused
        (asserts! (is-not-paused) ERR-CONTRACT-PAUSED)
        ;; Validate inputs
        (asserts! (is-valid-amount amount) ERR-INVALID-AMOUNT)
        (asserts! (not (is-eq owner recipient)) ERR-SELF-TRANSFER)
        
        (let (
            (owner-balance (get-balance-or-default owner))
            (current-allowance (get-allowance-or-default owner tx-sender))
        )
            ;; Check sufficient balance and allowance
            (asserts! (>= owner-balance amount) ERR-INSUFFICIENT-BALANCE)
            (asserts! (>= current-allowance amount) ERR-INSUFFICIENT-ALLOWANCE)
            
            ;; Update balances and allowance
            (set-balance owner (- owner-balance amount))
            (set-balance recipient (+ (get-balance-or-default recipient) amount))
            (set-allowance owner tx-sender (- current-allowance amount))
            
            ;; Print transfer event
            (print {
                action: "transfer-from",
                owner: owner,
                recipient: recipient,
                spender: tx-sender,
                amount: amount,
                memo: memo
            })
            
            (ok true)
        )
    )
)

;; Mint new tokens (only contract owner)
(define-public (mint (recipient principal) (amount uint))
    (begin
        ;; Check if contract is not paused
        (asserts! (is-not-paused) ERR-CONTRACT-PAUSED)
        ;; Only contract owner can mint
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (asserts! (is-valid-amount amount) ERR-INVALID-AMOUNT)
        
        (let (
            (current-supply (var-get total-supply))
            (new-supply (+ current-supply amount))
            (recipient-balance (get-balance-or-default recipient))
        )
            ;; Check max supply
            (asserts! (<= new-supply TOKEN-MAX-SUPPLY) ERR-MAX-SUPPLY-EXCEEDED)
            
            ;; Update total supply and recipient balance
            (var-set total-supply new-supply)
            (set-balance recipient (+ recipient-balance amount))
            
            ;; Print mint event
            (print {
                action: "mint",
                recipient: recipient,
                amount: amount,
                new-supply: new-supply
            })
            
            (ok true)
        )
    )
)

;; Burn tokens from sender's balance
(define-public (burn (amount uint))
    (begin
        ;; Check if contract is not paused
        (asserts! (is-not-paused) ERR-CONTRACT-PAUSED)
        (asserts! (is-valid-amount amount) ERR-INVALID-AMOUNT)
        
        (let (
            (sender-balance (get-balance-or-default tx-sender))
            (current-supply (var-get total-supply))
        )
            ;; Check sufficient balance
            (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
            
            ;; Update balance and total supply
            (set-balance tx-sender (- sender-balance amount))
            (var-set total-supply (- current-supply amount))
            
            ;; Print burn event
            (print {
                action: "burn",
                sender: tx-sender,
                amount: amount,
                new-supply: (- current-supply amount)
            })
            
            (ok true)
        )
    )
)

;; Transfer contract ownership (only current owner)
(define-public (transfer-ownership (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (let ((old-owner tx-sender))
            (var-set contract-owner new-owner)
            
            (print {
                action: "transfer-ownership",
                old-owner: old-owner,
                new-owner: new-owner
            })
            
            (ok true)
        )
    )
)

;; Get contract owner
(define-read-only (get-contract-owner)
    (ok (var-get contract-owner))
)

;; Pause contract (only owner)
(define-public (pause)
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (var-set token-paused true)
        
        (print {
            action: "pause",
            caller: tx-sender
        })
        
        (ok true)
    )
)

;; Unpause contract (only owner)
(define-public (unpause)
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (var-set token-paused false)
        
        (print {
            action: "unpause",
            caller: tx-sender
        })
        
        (ok true)
    )
)

;; Set token URI (only owner)
(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (var-set token-uri new-uri)
        
        (print {
            action: "set-token-uri",
            caller: tx-sender,
            new-uri: new-uri
        })
        
        (ok true)
    )
)

;; Get pause state
(define-read-only (is-paused)
    (ok (var-get token-paused))
)

;; Get current token URI
(define-read-only (get-current-uri)
    (ok (var-get token-uri))
)

;; Initialize contract with initial supply to deployer
(begin
    (let ((initial-supply u1000000000)) ;; 1000 tokens with 6 decimals
        (var-set total-supply initial-supply)
        (map-set balances CONTRACT-OWNER initial-supply)
        (print {
            action: "initialize",
            owner: CONTRACT-OWNER,
            initial-supply: initial-supply
        })
    )
)