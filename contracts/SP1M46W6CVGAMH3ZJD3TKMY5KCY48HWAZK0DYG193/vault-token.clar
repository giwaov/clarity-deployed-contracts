;; ========================================
;; VAULTAYIELD - VAULT SHARE TOKEN (SIP-010)
;; ========================================

;; NOTE: Uncomment for testnet/mainnet deployment
;; (impl-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; ========================================
;; ERROR CODES
;; ========================================

(define-constant ERR-NOT-AUTHORIZED (err u100))

;; ========================================
;; CONSTANTS
;; ========================================

(define-constant CONTRACT-OWNER tx-sender)

;; Token metadata
(define-constant TOKEN-NAME "VaultaYield Shares")
(define-constant TOKEN-SYMBOL "vySTX")
(define-constant TOKEN-DECIMALS u6)

;; ========================================
;; DATA VARIABLES
;; ========================================

(define-fungible-token vaultayield-shares)

(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var vault-core-contract (optional principal) none)

;; ========================================
;; SIP-010 FUNCTIONS
;; ========================================

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (or (is-eq tx-sender sender) (is-eq contract-caller sender)) ERR-NOT-AUTHORIZED)
    (try! (ft-transfer? vaultayield-shares amount sender recipient))
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
  (ok (ft-get-balance vaultayield-shares account))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply vaultayield-shares))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

;; ========================================
;; PRIVILEGED FUNCTIONS (Vault Core Only)
;; ========================================

(define-public (mint (amount uint) (recipient principal))
  ;; Only vault-core contract can mint
  (begin
    (asserts! (is-authorized-minter) ERR-NOT-AUTHORIZED)
    (ft-mint? vaultayield-shares amount recipient)
  )
)

(define-public (burn (amount uint) (owner principal))
  ;; Only vault-core contract can burn
  (begin
    (asserts! (is-authorized-minter) ERR-NOT-AUTHORIZED)
    (ft-burn? vaultayield-shares amount owner)
  )
)

;; ========================================
;; ADMIN FUNCTIONS
;; ========================================

(define-public (set-vault-core (vault-contract principal))
  ;; Set authorized vault core contract
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set vault-core-contract (some vault-contract))
    (ok true)
  )
)

(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set token-uri new-uri)
    (ok true)
  )
)

;; ========================================
;; PRIVATE FUNCTIONS
;; ========================================

(define-private (is-authorized-minter)
  ;; Check if caller is authorized vault core
  (match (var-get vault-core-contract)
    vault-contract (is-eq contract-caller vault-contract)
    false
  )
)
