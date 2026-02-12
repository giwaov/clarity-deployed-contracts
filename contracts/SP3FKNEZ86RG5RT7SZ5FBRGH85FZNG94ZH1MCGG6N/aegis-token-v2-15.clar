;; Aegis Token v3 - Governance Token
;; SIP-010 compliant fungible token for staking rewards
;; Part of the Aegis Vault split architecture

(impl-trait .sip-010-trait.sip-010-trait)

;; ============================================
;; CONSTANTS
;; ============================================

(define-constant CONTRACT-OWNER tx-sender)

;; Token metadata
(define-constant TOKEN-NAME "Aegis Token")
(define-constant TOKEN-SYMBOL "AGS")
(define-constant TOKEN-DECIMALS u6)
(define-constant TOKEN-URI (some u"https://aegis.finance/token-metadata.json"))

;; Supply limits
(define-constant MAX-SUPPLY u1000000000000000) ;; 1 billion tokens with 6 decimals

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u7001))
(define-constant ERR-NOT-TOKEN-OWNER (err u7002))
(define-constant ERR-INSUFFICIENT-BALANCE (err u7003))
(define-constant ERR-INVALID-AMOUNT (err u7004))
(define-constant ERR-MINTER-ONLY (err u7005))
(define-constant ERR-MAX-SUPPLY-REACHED (err u7006))

;; ============================================
;; DATA VARIABLES
;; ============================================

(define-data-var token-uri (optional (string-utf8 256)) TOKEN-URI)
(define-data-var total-supply uint u0)

;; ============================================
;; DATA MAPS
;; ============================================

(define-map balances principal uint)
(define-map allowances { owner: principal, spender: principal } uint)
(define-map authorized-minters principal bool)

;; ============================================
;; AUTHORIZATION
;; ============================================

(define-private (is-authorized-minter (caller principal))
  (or 
    (is-eq caller CONTRACT-OWNER)
    (default-to false (map-get? authorized-minters caller))
  )
)

;; ============================================
;; SIP-010 FUNCTIONS
;; ============================================

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (or (is-eq tx-sender sender) (is-eq contract-caller sender)) ERR-NOT-TOKEN-OWNER)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (try! (ft-transfer? ags-token amount sender recipient))
    (match memo to-print (print to-print) 0x)
    (ok true)
  )
)

(define-read-only (get-name)
  (ok TOKEN-NAME)
)

(define-read-only (get-symbol)
  (ok TOKEN-SYMBOL)
)

(define-read-only (get-decimals)
  (ok TOKEN-DECIMALS)
)

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance ags-token account))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply ags-token))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

;; ============================================
;; MINT & BURN
;; ============================================

(define-public (mint (recipient principal) (amount uint))
  (begin
    (asserts! (is-authorized-minter contract-caller) ERR-MINTER-ONLY)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= (+ (ft-get-supply ags-token) amount) MAX-SUPPLY) ERR-MAX-SUPPLY-REACHED)
    (try! (ft-mint? ags-token amount recipient))
    (print { event: "mint", recipient: recipient, amount: amount })
    (ok true)
  )
)

(define-public (burn (amount uint))
  (begin
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= (ft-get-balance ags-token tx-sender) amount) ERR-INSUFFICIENT-BALANCE)
    (try! (ft-burn? ags-token amount tx-sender))
    (print { event: "burn", burner: tx-sender, amount: amount })
    (ok true)
  )
)

;; ============================================
;; ADMIN FUNCTIONS
;; ============================================

(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set token-uri new-uri)
    (ok true)
  )
)

(define-public (add-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set authorized-minters minter true)
    (print { event: "minter-added", minter: minter })
    (ok true)
  )
)

(define-public (remove-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-delete authorized-minters minter)
    (print { event: "minter-removed", minter: minter })
    (ok true)
  )
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

(define-read-only (is-minter (account principal))
  (is-authorized-minter account)
)

(define-read-only (get-max-supply)
  MAX-SUPPLY
)

;; ============================================
;; FUNGIBLE TOKEN DEFINITION
;; ============================================

(define-fungible-token ags-token MAX-SUPPLY)
