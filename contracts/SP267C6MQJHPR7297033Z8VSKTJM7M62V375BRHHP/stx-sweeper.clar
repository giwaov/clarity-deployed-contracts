;; STX Sweeper & Vault
;; Version: Clarity 4

;; -------------------------
;; 1. CONSTANTS & VARIABLES
;; -------------------------

;; The principal that deploys the contract is the permanent owner
(define-constant CONTRACT-OWNER tx-sender)

;; 0.01 STX = 10,000 micro-STX (The amount to leave in the wallet)
(define-constant STX-BUFFER u10000)

;; Error Codes
(define-constant ERR-NOT-AUTHORIZED (err u403))
(define-constant ERR-INSUFFICIENT-FUNDS (err u101))
(define-constant ERR-TRANSFER-FAILED (err u102))

;; --------------------
;; 2. PUBLIC FUNCTIONS
;; --------------------

;; @desc Removes all STX from the caller's wallet except for 0.01 STX
;; @returns (response uint uint) - The amount of STX transferred
(define-public (drain)
    (let (
        ;; Get the current balance of the person calling the function
        (user-balance (stx-get-balance tx-sender))
    )
        ;; Check if the user has more than 0.01 STX
        (asserts! (> user-balance STX-BUFFER) ERR-INSUFFICIENT-FUNDS)

        (let (
            ;; Calculate the sweep amount: (Total - 0.01 STX)
            (sweep-amount (- user-balance STX-BUFFER))
        )
            ;; Transfer the sweep amount from the user to this contract
            ;; current-contract is a Clarity 4 keyword for this contract's address
            (try! (stx-transfer? sweep-amount tx-sender current-contract))
            
            (ok sweep-amount)
        )
    )
)

;; @desc Allows the CONTRACT-OWNER to withdraw all STX collected by the contract
;; @returns (response bool uint)
(define-public (withdraw-stx)
    (let (
        ;; Get the total amount of STX currently held in this contract
        (contract-balance (stx-get-balance current-contract))
    )
        ;; SECURITY: Only the person who deployed this contract can call this
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        
        ;; Clarity 4 as-contract? requires an explicit allowance list
        ;; We give the contract permission to spend its own 'contract-balance'
        (as-contract? ((with-stx contract-balance))
           (try! (stx-transfer? contract-balance current-contract CONTRACT-OWNER))
        )
    )
)

;; -----------------------
;; 3. READ-ONLY FUNCTIONS
;; -----------------------

;; @desc Returns the total STX currently stored in the contract vault
(define-read-only (get-vault-balance)
    (ok (stx-get-balance current-contract))
)
