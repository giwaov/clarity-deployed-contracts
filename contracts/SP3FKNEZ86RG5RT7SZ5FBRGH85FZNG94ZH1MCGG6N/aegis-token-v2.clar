;; Aegis Token V2 (AGS)
;; SIP-010 Compliant Fungible Token
;; Reward token for the Aegis Vault staking platform

(impl-trait .aegis-sip010-trait.sip-010-trait)

;; ============================================
;; CONSTANTS
;; ============================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u1001))
(define-constant ERR-NOT-TOKEN-OWNER (err u1002))
(define-constant ERR-INSUFFICIENT-BALANCE (err u1003))
(define-constant ERR-INVALID-AMOUNT (err u1004))
(define-constant ERR-MINTER-ONLY (err u1005))

;; Token metadata
(define-constant TOKEN-NAME "Aegis Token")
(define-constant TOKEN-SYMBOL "AGS")
(define-constant TOKEN-DECIMALS u6)
(define-constant TOKEN-URI (some u"https://aegis.finance/token-metadata.json"))

;; ============================================
;; DATA VARIABLES
;; ============================================

(define-data-var total-supply uint u0)
(define-data-var contract-paused bool false)

;; ============================================
;; DATA MAPS
;; ============================================

;; Token balances
(define-map balances principal uint)

;; Authorized minters (staking vault contract)
(define-map authorized-minters principal bool)

;; ============================================
;; PRIVATE FUNCTIONS
;; ============================================

(define-private (is-authorized-minter (account principal))
  (default-to false (map-get? authorized-minters account))
)

;; ============================================
;; SIP-010 IMPLEMENTATION
;; ============================================

;; Transfer tokens
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    ;; Validate sender is tx-sender or contract-caller
    (asserts! (or (is-eq tx-sender sender) (is-eq contract-caller sender)) ERR-NOT-TOKEN-OWNER)
    ;; Validate amount
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    ;; Check balance
    (asserts! (>= (get-balance-of sender) amount) ERR-INSUFFICIENT-BALANCE)
    
    ;; Update balances
    (map-set balances sender (- (get-balance-of sender) amount))
    (map-set balances recipient (+ (get-balance-of recipient) amount))
    
    ;; Print memo if provided
    (match memo
      memo-value (begin (print memo-value) true)
      true
    )
    
    (ok true)
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

;; Get decimals
(define-read-only (get-decimals)
  (ok TOKEN-DECIMALS)
)

;; Get balance of principal
(define-read-only (get-balance (account principal))
  (ok (get-balance-of account))
)

;; Get total supply
(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

;; Get token URI
(define-read-only (get-token-uri)
  (ok TOKEN-URI)
)

;; ============================================
;; HELPER READ-ONLY FUNCTIONS
;; ============================================

(define-read-only (get-balance-of (account principal))
  (default-to u0 (map-get? balances account))
)

(define-read-only (is-minter (account principal))
  (is-authorized-minter account)
)

(define-read-only (get-contract-owner)
  CONTRACT-OWNER
)

(define-read-only (is-paused)
  (var-get contract-paused)
)

;; ============================================
;; MINTING FUNCTIONS (Restricted to authorized minters)
;; ============================================

;; Mint tokens - only callable by authorized minters (staking vault)
(define-public (mint (amount uint) (recipient principal))
  (begin
    ;; Check if caller is authorized minter
    (asserts! (is-authorized-minter contract-caller) ERR-MINTER-ONLY)
    ;; Validate amount
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    ;; Update balance and supply
    (map-set balances recipient (+ (get-balance-of recipient) amount))
    (var-set total-supply (+ (var-get total-supply) amount))
    
    (print { event: "mint", amount: amount, recipient: recipient })
    (ok true)
  )
)

;; ============================================
;; ADMIN FUNCTIONS
;; ============================================

;; Add authorized minter (only contract owner)
(define-public (add-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set authorized-minters minter true)
    (print { event: "minter-added", minter: minter })
    (ok true)
  )
)

;; Remove authorized minter (only contract owner)
(define-public (remove-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-delete authorized-minters minter)
    (print { event: "minter-removed", minter: minter })
    (ok true)
  )
)

;; Pause contract (only contract owner)
(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set contract-paused true)
    (print { event: "contract-paused" })
    (ok true)
  )
)

;; Unpause contract (only contract owner)
(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set contract-paused false)
    (print { event: "contract-unpaused" })
    (ok true)
  )
)

;; ============================================
;; BURN FUNCTION (Optional - for future use)
;; ============================================

;; Burn tokens from own balance
(define-public (burn (amount uint))
  (let
    (
      (sender tx-sender)
      (sender-balance (get-balance-of sender))
    )
    ;; Validate amount
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    ;; Check balance
    (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
    
    ;; Update balance and supply
    (map-set balances sender (- sender-balance amount))
    (var-set total-supply (- (var-get total-supply) amount))
    
    (print { event: "burn", amount: amount, burner: sender })
    (ok true)
  )
)
